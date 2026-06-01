import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import { Construct } from 'constructs';

export class EksFargateStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // VPC with public and private subnets
    const vpc = new ec2.Vpc(this, 'EksVpc', {
      maxAzs: 2,
      natGateways: 1,
      subnetConfiguration: [
        {
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: 'private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
      ],
    });

    // EKS Cluster with Fargate
    const cluster = new eks.Cluster(this, 'EksFargateCluster', {
      vpc,
      version: eks.KubernetesVersion.V1_30,
      defaultCapacity: 0, // No node group, use Fargate
      albController: {
        version: eks.AlbControllerVersion.V2_8_2,
      },
    });

    // Fargate profile for the microservice namespace
    const fargateProfile = new eks.FargateProfile(this, 'FargateProfile', {
      cluster,
      selectors: [
        {
          namespace: 'microservice',
        },
      ],
      vpc,
      subnetSelection: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
    });

    // IAM role for the microservice service account
    const serviceAccountRole = new iam.Role(this, 'MicroserviceServiceAccountRole', {
      assumedBy: new iam.ServicePrincipal('pods.eks.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEKSFargatePodExecutionRolePolicy'),
      ],
    });

    // Kubernetes service account for the microservice
    const serviceAccount = new eks.ServiceAccount(this, 'MicroserviceServiceAccount', {
      cluster,
      name: 'microservice-sa',
      namespace: 'microservice',
      role: serviceAccountRole,
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
            serviceAccountName: 'microservice-sa',
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
      metadata: { name: 'microservice-svc', namespace: 'microservice' },
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
                      name: 'microservice-svc',
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

    // Apply the manifests to the cluster
    new eks.KubernetesManifest(this, 'MicroserviceDeployment', {
      cluster,
      manifest: [deploymentManifest],
      overwrite: true,
    });

    new eks.KubernetesManifest(this, 'MicroserviceService', {
      cluster,
      manifest: [serviceManifest],
      overwrite: true,
    });

    new eks.KubernetesManifest(this, 'MicroserviceIngress', {
      cluster,
      manifest: [ingressManifest],
      overwrite: true,
    });

    // Output the ALB DNS name
    new cdk.CfnOutput(this, 'AlbDnsName', {
      value: cluster.albController?.loadBalancerDnsName || 'ALB not yet provisioned',
      description: 'DNS name of the internet-facing ALB',
    });
  }
}