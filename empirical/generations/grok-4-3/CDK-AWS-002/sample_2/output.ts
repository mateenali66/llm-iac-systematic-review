import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as s3 from 'aws-cdk-lib/aws-s3';
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
          name: 'Private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
        {
          cidrMask: 24,
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
        },
      ],
    });

    const cluster = new eks.FargateCluster(this, 'MicroserviceCluster', {
      version: eks.KubernetesVersion.V1_29,
      vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
        eks.ClusterLoggingTypes.CONTROLLER_MANAGER,
        eks.ClusterLoggingTypes.SCHEDULER,
      ],
      coreDnsComputeType: eks.CoreDnsComputeType.FARGATE,
      albController: {
        version: eks.AlbControllerVersion.V2_6_2,
      },
      outputClusterName: true,
      outputConfigCommand: true,
    });

    const appNamespace = cluster.addManifest('AppNamespace', {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: { name: 'microservice' },
    });

    const deployment = cluster.addManifest('MicroserviceDeployment', {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'microservice',
        namespace: 'microservice',
      },
      spec: {
        replicas: 3,
        selector: { matchLabels: { app: 'microservice' } },
        template: {
          metadata: { labels: { app: 'microservice' } },
          spec: {
            containers: [
              {
                name: 'microservice',
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
    });
    deployment.node.addDependency(appNamespace);

    const service = cluster.addManifest('MicroserviceService', {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'microservice',
        namespace: 'microservice',
        annotations: {
          'service.beta.kubernetes.io/aws-load-balancer-type': 'external',
          'service.beta.kubernetes.io/aws-load-balancer-scheme': 'internet-facing',
          'service.beta.kubernetes.io/aws-load-balancer-target-type': 'ip',
          'service.beta.kubernetes.io/aws-load-balancer-attributes': 'idle_timeout.timeout_seconds=60',
        },
      },
      spec: {
        type: 'LoadBalancer',
        selector: { app: 'microservice' },
        ports: [{ port: 80, targetPort: 80 }],
      },
    });
    service.node.addDependency(deployment);

    new cdk.CfnOutput(this, 'LoadBalancerDNS', {
      value: `kubectl get svc microservice -n microservice -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`,
      description: 'Run this command after deployment to get ALB DNS name',
    });
  }
}

const app = new cdk.App();
new EksFargateMicroserviceStack(app, 'EksFargateMicroserviceStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
});