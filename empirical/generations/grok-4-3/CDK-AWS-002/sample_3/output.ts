import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';

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

    const cluster = new eks.FargateCluster(this, 'EksFargateCluster', {
      clusterName: 'microservice-cluster',
      version: eks.KubernetesVersion.V1_28,
      vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
      coreDnsComputeType: eks.CoreDnsComputeType.FARGATE,
      albController: {
        version: eks.AlbControllerVersion.V2_6_2,
      },
      endpointAccess: eks.EndpointAccess.PRIVATE,
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
      metadata: { name: 'microservice', namespace: 'microservice' },
      spec: {
        replicas: 3,
        selector: { matchLabels: { app: 'microservice' } },
        template: {
          metadata: { labels: { app: 'microservice' } },
          spec: {
            containers: [{
              name: 'microservice',
              image: 'public.ecr.aws/nginx/nginx:latest',
              ports: [{ containerPort: 80 }],
              resources: {
                requests: { cpu: '100m', memory: '128Mi' },
                limits: { cpu: '200m', memory: '256Mi' },
              },
            }],
          },
        },
      },
    });
    deployment.node.addDependency(appNamespace);

    const service = cluster.addManifest('MicroserviceService', {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: { name: 'microservice', namespace: 'microservice' },
      spec: {
        selector: { app: 'microservice' },
        ports: [{ port: 80, targetPort: 80 }],
        type: 'ClusterIP',
      },
    });
    service.node.addDependency(deployment);

    const ingress = cluster.addManifest('MicroserviceIngress', {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'Ingress',
      metadata: {
        name: 'microservice-ingress',
        namespace: 'microservice',
        annotations: {
          'alb.ingress.kubernetes.io/scheme': 'internet-facing',
          'alb.ingress.kubernetes.io/target-type': 'ip',
          'alb.ingress.kubernetes.io/listen-ports': '[{"HTTP":80},{"HTTPS":443}]',
          'alb.ingress.kubernetes.io/ssl-redirect': '443',
        },
      },
      spec: {
        ingressClassName: 'alb',
        rules: [{
          http: {
            paths: [{
              path: '/',
              pathType: 'Prefix',
              backend: {
                service: {
                  name: 'microservice',
                  port: { number: 80 },
                },
              },
            }],
          },
        }],
      },
    });
    ingress.node.addDependency(service);
  }
}