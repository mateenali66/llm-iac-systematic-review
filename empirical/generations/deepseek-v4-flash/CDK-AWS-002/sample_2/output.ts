import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import { Construct } from 'constructs';

export class EksFargateMicroserviceStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // VPC with public and private subnets
    const vpc = new ec2.Vpc(this, 'EksVpc', {
      maxAzs: 2,
      natGateways: 1,
      subnetConfiguration: [
        {
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: 'Private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
      ],
    });

    // EKS Cluster with Fargate
    const cluster = new eks.Cluster(this, 'FargateCluster', {
      vpc,
      version: eks.KubernetesVersion.V1_30,
      defaultCapacity: 0, // No managed node group
      albController: {
        version: eks.AlbControllerVersion.V2_8_2,
      },
    });

    // Fargate profile for the microservice namespace
    const fargateProfile = cluster.addFargateProfile('FargateProfile', {
      selectors: [
        {
          namespace: 'microservice',
        },
      ],
      vpc,
    });

    // IAM role for the microservice pod execution
    const podExecutionRole = new iam.Role(this, 'PodExecutionRole', {
      assumedBy: new iam.ServicePrincipal('eks-fargate-pods.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEKSFargatePodExecutionRolePolicy'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEKS_CNI_Policy'),
      ],
    });

    // Deploy the microservice using a Kubernetes manifest
    const deploymentManifest = {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: { name: 'microservice', namespace: 'microservice' },
      spec: {
        replicas: 2,
        selector: { matchLabels: { app: 'microservice' } },
        template: {
          metadata: { labels: { app: 'microservice' } },
          spec: {
            serviceAccountName: 'default',
            containers: [
              {
                name: 'app',
                image: 'nginx:latest', // Replace with your microservice image
                ports: [{ containerPort: 80 }],
                resources: {
                  requests: { cpu: '256m', memory: '512Mi' },
                  limits: { cpu: '512m', memory: '1024Mi' },
                },
              },
            ],
          },
        },
      },
    };

    const serviceManifest = {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'microservice-service',
        namespace: 'microservice',
        annotations: {
          'alb.ingress.kubernetes.io/scheme': 'internet-facing',
          'alb.ingress.kubernetes.io/target-type': 'ip',
        },
      },
      spec: {
        type: 'NodePort',
        selector: { app: 'microservice' },
        ports: [{ port: 80, targetPort: 80 }],
      },
    };

    const ingressManifest = {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'Ingress',
      metadata: {
        name: 'microservice-ingress',
        namespace: 'microservice',
        annotations: {
          'alb.ingress.kubernetes.io/scheme': 'internet-facing',
          'alb.ingress.kubernetes.io/target-type': 'ip',
          'alb.ingress.kubernetes.io/listen-ports': '[{"HTTP": 80}]',
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
                      name: 'microservice-service',
                      port: { number: 80 },
                    },
                  },
                },
              ],
            },
          },
        ],
      },
    };

    // Create namespace first
    const namespaceManifest = {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: { name: 'microservice' },
    };

    // Apply Kubernetes manifests
    const namespace = cluster.addManifest('MicroserviceNamespace', namespaceManifest);
    const deployment = cluster.addManifest('MicroserviceDeployment', deploymentManifest);
    const service = cluster.addManifest('MicroserviceService', serviceManifest);
    const ingress = cluster.addManifest('MicroserviceIngress', ingressManifest);

    // Ensure ordering
    deployment.node.addDependency(namespace);
    service.node.addDependency(deployment);
    ingress.node.addDependency(service);

    // Output the ALB DNS name
    new cdk.CfnOutput(this, 'AlbDnsName', {
      value: 'http://<alb-dns-name>', // Replace with actual ALB DNS after deployment
      description: 'The DNS name of the ALB',
    });
  }
}