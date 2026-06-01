import * as cdk from 'aws-cdk-lib';
import { Stack, StackProps, RemovalPolicy, CfnOutput, Duration } from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as kms from 'aws-cdk-lib/aws-kms';
import * as logs from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';

export class EksFargateAlbStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // VPC with public and private subnets across 3 AZs and 2 NAT gateways for HA
    const vpc = new ec2.Vpc(this, 'Vpc', {
      maxAzs: 3,
      natGateways: 2,
      subnetConfiguration: [
        { name: 'public', subnetType: ec2.SubnetType.PUBLIC, cidrMask: 24 },
        { name: 'private-egress', subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS, cidrMask: 24 },
      ],
    });

    // VPC Flow Logs to CloudWatch for visibility
    const flowLogsGroup = new logs.LogGroup(this, 'VpcFlowLogsGroup', {
      retention: logs.RetentionDays.ONE_YEAR,
      removalPolicy: RemovalPolicy.RETAIN,
    });
    vpc.addFlowLog('VpcFlowLogs', {
      destination: ec2.FlowLogDestination.toCloudWatchLogs(flowLogsGroup),
      trafficType: ec2.FlowLogTrafficType.ALL,
    });

    // KMS key for EKS secret encryption
    const eksKmsKey = new kms.Key(this, 'EksSecretsKey', {
      enableKeyRotation: true,
      alias: 'alias/eks-secrets',
      removalPolicy: RemovalPolicy.RETAIN,
    });

    // EKS Fargate Cluster
    const cluster = new eks.FargateCluster(this, 'EksFargateCluster', {
      vpc,
      version: eks.KubernetesVersion.V1_29,
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
      secretsEncryptionKey: eksKmsKey,
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.SCHEDULER,
        eks.ClusterLoggingTypes.CONTROLLER_MANAGER,
      ],
    });

    // Fargate profile for the application namespace
    cluster.addFargateProfile('AppFargateProfile', {
      selectors: [{ namespace: 'app' }],
      subnetSelection: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
    });

    // AWS Load Balancer Controller (installs required IAM + Helm chart)
    const albController = new eks.AlbController(this, 'AlbController', {
      cluster,
      version: eks.AlbControllerVersion.V2_6_1,
    });

    // Kubernetes Namespace for the app
    const appNs = cluster.addManifest('AppNamespace', {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: { name: 'app', labels: { name: 'app' } },
    });

    // Application Deployment (non-root NGINX unprivileged on port 8080)
    const appDeployment = cluster.addManifest('AppDeployment', {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'app-deployment',
        namespace: 'app',
        labels: { app: 'web' },
      },
      spec: {
        replicas: 3,
        selector: { matchLabels: { app: 'web' } },
        template: {
          metadata: {
            labels: { app: 'web' },
          },
          spec: {
            securityContext: {
              runAsNonRoot: true,
              fsGroup: 2000,
            },
            containers: [
              {
                name: 'web',
                image: 'nginxinc/nginx-unprivileged:1.25-alpine',
                ports: [{ containerPort: 8080 }],
                resources: {
                  requests: { cpu: '100m', memory: '128Mi' },
                  limits: { cpu: '500m', memory: '256Mi' },
                },
                securityContext: {
                  allowPrivilegeEscalation: false,
                  readOnlyRootFilesystem: true,
                  capabilities: { drop: ['ALL'] },
                },
                livenessProbe: {
                  httpGet: { path: '/', port: 8080 },
                  initialDelaySeconds: 10,
                  periodSeconds: 10,
                  timeoutSeconds: 5,
                  failureThreshold: 3,
                },
                readinessProbe: {
                  httpGet: { path: '/', port: 8080 },
                  initialDelaySeconds: 5,
                  periodSeconds: 5,
                  timeoutSeconds: 3,
                  failureThreshold: 3,
                },
                env: [
                  { name: 'APP_NAME', value: 'eks-fargate-alb-svc' },
                ],
              },
            ],
          },
        },
      },
    });
    appDeployment.node.addDependency(appNs);

    // ClusterIP Service for the Deployment
    const appService = cluster.addManifest('AppService', {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'app-service',
        namespace: 'app',
        labels: { app: 'web' },
      },
      spec: {
        type: 'ClusterIP',
        selector: { app: 'web' },
        ports: [
          {
            name: 'http',
            port: 80,
            targetPort: 8080,
            protocol: 'TCP',
          },
        ],
      },
    });
    appService.node.addDependency(appDeployment);

    // Ingress with AWS Load Balancer Controller to provision internet-facing ALB
    const appIngress = cluster.addManifest('AppIngress', {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'Ingress',
      metadata: {
        name: 'app-ingress',
        namespace: 'app',
        annotations: {
          'kubernetes.io/ingress.class': 'alb',
          'alb.ingress.kubernetes.io/scheme': 'internet-facing',
          'alb.ingress.kubernetes.io/target-type': 'ip',
          'alb.ingress.kubernetes.io/healthcheck-path': '/',
          'alb.ingress.kubernetes.io/healthcheck-interval-seconds': '15',
          'alb.ingress.kubernetes.io/healthy-threshold-count': '2',
          'alb.ingress.kubernetes.io/unhealthy-threshold-count': '5',
          'alb.ingress.kubernetes.io/listen-ports': '[{"HTTP":80}]',
        },
      },
      spec: {
        ingressClassName: 'alb',
        rules: [
          {
            http: {
              paths: [
                {
                  path: '/',
                  pathType: 'Prefix',
                  backend: {
                    service: {
                      name: 'app-service',
                      port: { number: 80 },
                    },
                  },
                },
              ],
            },
          },
        ],
      },
    });
    appIngress.node.addDependency(appService);
    appIngress.node.addDependency(albController);

    new CfnOutput(this, 'ClusterName', { value: cluster.clusterName });
    new CfnOutput(this, 'VpcId', { value: vpc.vpcId });
  }
}

const app = new cdk.App();
new EksFargateAlbStack(app, 'EksFargateAlbStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
});