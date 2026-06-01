import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
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
    const cluster = new eks.Cluster(this, 'EksFargateCluster', {
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
    });

    // Namespace for the microservice
    const namespace = cluster.addManifest('MicroserviceNamespace', {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: { name: 'microservice' },
    });

    // Service Account for ALB Ingress Controller
    const albServiceAccount = cluster.addServiceAccount('AlbIngressController', {
      name: 'aws-load-balancer-controller',
      namespace: 'kube-system',
    });

    // Grant necessary permissions for ALB controller
    albServiceAccount.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: [
          'elasticloadbalancing:CreateListener',
          'elasticloadbalancing:CreateRule',
          'elasticloadbalancing:CreateTargetGroup',
          'elasticloadbalancing:DeleteListener',
          'elasticloadbalancing:DeleteRule',
          'elasticloadbalancing:DeleteTargetGroup',
          'elasticloadbalancing:DeregisterTargets',
          'elasticloadbalancing:DescribeListeners',
          'elasticloadbalancing:DescribeRules',
          'elasticloadbalancing:DescribeTargetGroups',
          'elasticloadbalancing:DescribeTargetHealth',
          'elasticloadbalancing:ModifyListener',
          'elasticloadbalancing:ModifyRule',
          'elasticloadbalancing:ModifyTargetGroup',
          'elasticloadbalancing:RegisterTargets',
          'elasticloadbalancing:SetIpAddressType',
          'elasticloadbalancing:SetSecurityGroups',
          'elasticloadbalancing:SetSubnets',
          'ec2:DescribeSecurityGroups',
          'ec2:DescribeSubnets',
          'ec2:DescribeVpcs',
          'iam:CreateServiceLinkedRole',
          'wafv2:GetWebACL',
          'wafv2:AssociateWebACL',
          'wafv2:DisassociateWebACL',
        ],
        resources: ['*'],
      })
    );

    // Deploy microservice deployment
    const deployment = cluster.addManifest('MicroserviceDeployment', {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'microservice',
        namespace: 'microservice',
        labels: { app: 'microservice' },
      },
      spec: {
        replicas: 2,
        selector: { matchLabels: { app: 'microservice' } },
        template: {
          metadata: { labels: { app: 'microservice' } },
          spec: {
            containers: [
              {
                name: 'app',
                image: 'nginx:alpine', // Replace with your microservice image
                ports: [{ containerPort: 80 }],
                resources: {
                  requests: { cpu: '256m', memory: '512Mi' },
                  limits: { cpu: '512m', memory: '1Gi' },
                },
              },
            ],
          },
        },
      },
    });

    // Deploy microservice service
    const service = cluster.addManifest('MicroserviceService', {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'microservice',
        namespace: 'microservice',
        annotations: {
          'alb.ingress.kubernetes.io/target-type': 'ip',
        },
      },
      spec: {
        type: 'NodePort',
        selector: { app: 'microservice' },
        ports: [{ port: 80, targetPort: 80 }],
      },
    });

    // Deploy Ingress resource for ALB
    const ingress = cluster.addManifest('MicroserviceIngress', {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'Ingress',
      metadata: {
        name: 'microservice-ingress',
        namespace: 'microservice',
        annotations: {
          'alb.ingress.kubernetes.io/scheme': 'internet-facing',
          'alb.ingress.kubernetes.io/target-type': 'ip',
          'alb.ingress.kubernetes.io/listen-ports': '[{"HTTP": 80}]',
          'alb.ingress.kubernetes.io/healthcheck-path': '/',
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
                      name: 'microservice',
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

    // Output the ALB DNS name
    new cdk.CfnOutput(this, 'AlbDnsName', {
      value: 'http://' + cluster.clusterName + '-alb-xxxxxxxxxx.us-east-1.elb.amazonaws.com', // Placeholder - actual DNS will be available after deployment
      description: 'DNS name of the ALB (replace with actual after deployment)',
    });
  }
}