import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import { KubectlV31Layer } from '@aws-cdk/lambda-layer-kubectl-v31';
import { Construct } from 'constructs';

export interface EksFargateMicroserviceStackProps extends cdk.StackProps {
  readonly clusterName?: string;
  readonly containerImage?: string;
  readonly containerPort?: number;
  readonly replicas?: number;
  readonly namespace?: string;
}

export class EksFargateMicroserviceStack extends cdk.Stack {
  public readonly cluster: eks.Cluster;
  public readonly albAddress: cdk.CfnOutput;

  constructor(scope: Construct, id: string, props: EksFargateMicroserviceStackProps = {}) {
    super(scope, id, props);

    const clusterName = props.clusterName ?? 'eks-fargate-microservice';
    const containerImage = props.containerImage ?? 'public.ecr.aws/nginx/nginx:1.27';
    const containerPort = props.containerPort ?? 80;
    const replicas = props.replicas ?? 3;
    const namespace = props.namespace ?? 'app';

    const vpc = new ec2.Vpc(this, 'ClusterVpc', {
      maxAzs: 3,
      natGateways: 2,
      subnetConfiguration: [
        { name: 'public', subnetType: ec2.SubnetType.PUBLIC, cidrMask: 24 },
        { name: 'private', subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS, cidrMask: 22 },
      ],
      flowLogs: {
        cw: {
          trafficType: ec2.FlowLogTrafficType.ALL,
        },
      },
    });

    const masterRole = new iam.Role(this, 'ClusterAdminRole', {
      assumedBy: new iam.AccountRootPrincipal(),
      description: 'Admin role for EKS cluster access via kubectl',
    });

    const cluster = new eks.FargateCluster(this, 'FargateCluster', {
      version: eks.KubernetesVersion.V1_31,
      kubectlLayer: new KubectlV31Layer(this, 'KubectlLayer'),
      clusterName,
      vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
      mastersRole: masterRole,
      defaultProfile: {
        selectors: [
          { namespace: 'default' },
          { namespace: 'kube-system' },
          { namespace },
        ],
      },
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
        eks.ClusterLoggingTypes.CONTROLLER_MANAGER,
        eks.ClusterLoggingTypes.SCHEDULER,
      ],
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
      albController: {
        version: eks.AlbControllerVersion.V2_8_2,
      },
    });
    this.cluster = cluster;

    const appNamespace = cluster.addManifest('AppNamespace', {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: { name: namespace },
    });

    const appLabel = { app: 'microservice' };

    const deployment = cluster.addManifest('AppDeployment', {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: { name: 'microservice', namespace },
      spec: {
        replicas,
        selector: { matchLabels: appLabel },
        template: {
          metadata: { labels: appLabel },
          spec: {
            automountServiceAccountToken: false,
            securityContext: {
              runAsNonRoot: true,
              runAsUser: 1000,
              fsGroup: 2000,
              seccompProfile: { type: 'RuntimeDefault' },
            },
            containers: [
              {
                name: 'microservice',
                image: containerImage,
                imagePullPolicy: 'IfNotPresent',
                ports: [{ containerPort, name: 'http' }],
                resources: {
                  requests: { cpu: '250m', memory: '512Mi' },
                  limits: { cpu: '500m', memory: '1Gi' },
                },
                securityContext: {
                  allowPrivilegeEscalation: false,
                  readOnlyRootFilesystem: true,
                  capabilities: { drop: ['ALL'] },
                },
                livenessProbe: {
                  httpGet: { path: '/', port: 'http' },
                  initialDelaySeconds: 15,
                  periodSeconds: 20,
                },
                readinessProbe: {
                  httpGet: { path: '/', port: 'http' },
                  initialDelaySeconds: 5,
                  periodSeconds: 10,
                },
                volumeMounts: [
                  { name: 'tmp', mountPath: '/tmp' },
                  { name: 'cache', mountPath: '/var/cache/nginx' },
                  { name: 'run', mountPath: '/var/run' },
                ],
              },
            ],
            volumes: [
              { name: 'tmp', emptyDir: {} },
              { name: 'cache', emptyDir: {} },
              { name: 'run', emptyDir: {} },
            ],
          },
        },
      },
    });
    deployment.node.addDependency(appNamespace);

    const service = cluster.addManifest('AppService