import * as cdk from 'aws-cdk-lib';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export class EksFargateStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create VPC with public and private subnets
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
        }
      ]
    });

    // Create EKS cluster with Fargate profiles
    const cluster = new eks.Cluster(this, 'EksCluster', {
      vpc,
      version: eks.KubernetesVersion.V1_28,
      clusterName: 'fargate-cluster',
      defaultCapacity: 0,
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
      mastersRole: new iam.Role(this, 'EksAdminRole', {
        assumedBy: new iam.AccountRootPrincipal(),
      }),
    });

    // Add Fargate profile for application workloads
    cluster.addFargateProfile('ApplicationProfile', {
      selectors: [
        {
          namespace: 'default',
          labels: {
            'fargate.enabled': 'true'
          }
        }
      ],
      subnetSelection: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS
      }
    });

    // Add Fargate profile for Kubernetes system components
    cluster.addFargateProfile('SystemProfile', {
      selectors: [
        {
          namespace: 'kube-system',
          labels: {
            'k8s-app': 'kube-dns'
          }
        }
      ],
      subnetSelection: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS
      }
    });

    // Create Kubernetes manifest for the microservice
    const appManifest = {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'microservice-deployment',
        namespace: 'default',
        labels: {
          app: 'microservice'
        }
      },
      spec: {
        replicas: 3,
        selector: {
          matchLabels: {
            app: 'microservice'
          }
        },
        template: {
          metadata: {
            labels: {
              app: 'microservice',
              'fargate.enabled': 'true'
            }
          },
          spec: {
            containers: [
              {
                name: 'microservice',
                image: 'nginx:latest',
                ports: [
                  {
                    containerPort: 80
                  }
                ],
                resources: {
                  requests: {
                    cpu: '250m',
                    memory: '512Mi'
                  },
                  limits: {
                    cpu: '500m',
                    memory: '1Gi'
                  }
                }
              }
            ]
          }
        }
      }
    };

    // Create Kubernetes service manifest
    const serviceManifest = {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'microservice-service',
        namespace: 'default',
        annotations: {
          'service.beta.kubernetes.io/aws-load-balancer-type': 'external',
          'service.beta.kubernetes.io/aws-load-balancer-nlb-target-type': 'ip',
          'service.beta.kubernetes.io/aws-load-balancer-scheme': 'internet-facing'
        }
      },
      spec: {
        type: 'LoadBalancer',
        selector: {
          app: 'microservice'
        },
        ports: [
          {
            port: 80,
            targetPort: 80,
            protocol: 'TCP'
          }
        ]
      }
    };

    // Deploy manifests to the cluster
    new eks.KubernetesManifest(this, 'MicroserviceDeployment', {
      cluster,
      manifest: [appManifest],
      overwrite: true
    });

    new eks.KubernetesManifest(this, 'MicroserviceService', {
      cluster,
      manifest: [serviceManifest],
      overwrite: true
    });

    // Output cluster endpoint and certificate authority data
    new cdk.CfnOutput(this, 'ClusterEndpoint', {
      value: cluster.clusterEndpoint,
      description: 'EKS Cluster Endpoint'
    });

    new cdk.CfnOutput(this, 'ClusterArn', {
      value: cluster.clusterArn,
      description: 'EKS Cluster ARN'
    });
  }
}