import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export class EksFargateMicroserviceStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'EksVpc', {
      maxAzs: 3,
      natGateways: 1,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          cidrMask: 24,
          name: 'Private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
      ],
    });

    const cluster = new eks.FargateCluster(this, 'EksFargateCluster', {
      version: eks.KubernetesVersion.V1_28,
      vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
        eks.ClusterLoggingTypes.CONTROLLER_MANAGER,
        eks.ClusterLoggingTypes.SCHEDULER,
      ],
      albController: {
        version: eks.AlbControllerVersion.V2_6_2,
      },
      coreDnsComputeType: eks.CoreDnsComputeType.FARGATE,
      outputClusterName: true,
      outputConfigCommand: true,
    });

    const appManifest = {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: { name: 'microservice' },
    };
    cluster.addManifest('MicroserviceNamespace', appManifest);

    const deployment = {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: { name: 'microservice', namespace: 'microservice' },
      spec: {
        replicas: 3,
        selector: { matchLabels: { app: 'microservice' } },
        template: {
          metadata: { labels: { app: 'microservice' } },
          spec: {
            containers: [
              {
                name: 'app',
                image: 'public.ecr.aws/nginx/nginx:1.25',
                ports: [{ containerPort: 80 }],
                resources: {
                  requests: { cpu: '100m', memory: '128Mi' },
                  limits: { cpu: '200m', memory: '256Mi' },
                },
              },
            ],
          },
        },
      },
    };
    cluster.addManifest('MicroserviceDeployment', deployment);

    const service = {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'microservice',
        namespace: 'microservice',
        annotations: {
          'alb.ingress.kubernetes.io/scheme': 'internet-facing',
          'alb.ingress.kubernetes.io/target-type': 'ip',
          'alb.ingress.kubernetes.io/healthcheck-path': '/',
        },
      },
      spec: {
        type: 'LoadBalancer',
        selector: { app: 'microservice' },
        ports: [{ port: 80, targetPort: 80 }],
      },
    };
    cluster.addManifest('MicroserviceService', service);
  }
}