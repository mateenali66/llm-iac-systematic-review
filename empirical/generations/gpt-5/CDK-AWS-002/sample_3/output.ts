import * as cdk from 'aws-cdk-lib';
import { App, Stack, StackProps, Tags } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as kms from 'aws-cdk-lib/aws-kms';

export class EksFargateAlbStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'Vpc', {
      maxAzs: 2,
      natGateways: 2,
      subnetConfiguration: [
        { name: 'public', subnetType: ec2.SubnetType.PUBLIC },
        { name: 'private-egress', subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
      ],
    });

    const kmsKey = new kms.Key(this, 'EksSecretsKey', {
      enableKeyRotation: true,
      description: 'KMS key for EKS secrets encryption',
    });

    const cluster = new eks.Cluster(this, 'EksCluster', {
      version: eks.KubernetesVersion.V1_29,
      vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
      defaultCapacity: 0,
      endpointAccess: eks.EndpointAccess.PRIVATE,
      secretsEncryptionKey: kmsKey,
      placeClusterHandlerInVpc: true,
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
      ],
    });

    for (const subnet of vpc.publicSubnets) {
      Tags.of(subnet).add('kubernetes.io/role/elb', '1');
      Tags.of(subnet).add(`kubernetes.io/cluster/${cluster.clusterName}`, 'shared');
    }
    for (const subnet of vpc.privateSubnets) {
      Tags.of(subnet).add('kubernetes.io/role/internal-elb', '1');
      Tags.of(subnet).add(`kubernetes.io/cluster/${cluster.clusterName}`, 'shared');
    }

    cluster.addFargateProfile('CoreDnsProfile', {
      selectors: [{ namespace: 'kube-system', labels: { 'k8s-app': 'kube-dns' } }],
      subnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
    });

    cluster.addFargateProfile('AppFargateProfile', {
      selectors: [{ namespace: 'app' }],
      subnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
    });

    new eks.AlbController(this, 'AlbController', {
      cluster,
      version: eks.AlbControllerVersion.V2_6_1,
    });

    const ns = cluster.addManifest('AppNamespace', {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: { name: 'app' },
    });

    const appDeployment = cluster.addManifest('AppDeployment', {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: { name: 'web-deployment', namespace: 'app' },
      spec: {
        replicas: 2,
        selector: { matchLabels: { app: 'web' } },
        template: {
          metadata: { labels: { app: 'web' } },
          spec: {
            containers: [
              {
                name: 'web',
                image: 'public.ecr.aws/bitnami/nginx:1.25.3',
                ports: [{ containerPort: 8080 }],
                resources: {
                  requests: { cpu: '250m', memory: '512Mi' },
                  limits: { cpu: '500m', memory: '1Gi' },
                },
                readinessProbe: {
                  httpGet: { path: '/', port: 8080 },
                  initialDelaySeconds: 5,
                  periodSeconds: 10,
                },
                livenessProbe: {
                  httpGet: { path: '/', port: 8080 },
                  initialDelaySeconds: 10,
                  periodSeconds: 20,
                },
              },
            ],
          },
        },
      },
    });
    appDeployment.node.addDependency(ns);

    const svc = cluster.addManifest('AppService', {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: { name: 'web-svc', namespace: 'app' },
      spec: {
        type: 'ClusterIP',
        selector: { app: 'web' },
        ports: [
          { name: 'http', port: 80, targetPort: 8080 },
        ],
      },
    });
    svc.node.addDependency(appDeployment);

    const ingress = cluster.addManifest('AppIngress', {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'Ingress',
      metadata: {
        name: 'web-ingress',
        namespace: 'app',
        annotations: {
          'kubernetes.io/ingress.class': 'alb',
          'alb.ingress.kubernetes.io/scheme': 'internet-facing',
          'alb.ingress.kubernetes.io/target-type': 'ip',
          'alb.ingress.kubernetes.io/listen-ports': '[{"HTTP":80}]',
          'alb.ingress.kubernetes.io/healthcheck-path': '/',
        },
      },
      spec: {
        rules: [
          {
            http: {
              paths: [
                {
                  path: '/',
                  pathType: 'Prefix',
                  backend: {
                    service: {
                      name: 'web-svc',
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
    ingress.node.addDependency(svc);
  }
}

const app = new App();
new EksFargateAlbStack(app, 'EksFargateAlbStack');