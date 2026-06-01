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
        }
      ]
    });

    // Create EKS cluster with Fargate profiles
    const cluster = new eks.FargateCluster(this, 'EksCluster', {
      version: eks.KubernetesVersion.V1_28,
      vpc: vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
      defaultProfile: {
        fargateProfileName: 'default-profile',
        selectors: [
          { namespace: 'default' },
          { namespace: 'kube-system' }
        ]
      }
    });

    // Add additional Fargate profile for our application
    cluster.addFargateProfile('AppProfile', {
      fargateProfileName: 'app-profile',
      selectors: [
        { namespace: 'app' }
      ]
    });

    // Create Kubernetes manifest for the microservice
    const appNamespace = cluster.addManifest('AppNamespace', {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: {
        name: 'app'
      }
    });

    // Create deployment manifest
    const deployment = cluster.addManifest('MicroserviceDeployment', {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'microservice',
        namespace: 'app'
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
              app: 'microservice'
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
    });
    deployment.node.addDependency(appNamespace);

    // Create service manifest
    const service = cluster.addManifest('MicroserviceService', {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'microservice-service',
        namespace: 'app',
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
    });
    service.node.addDependency(deployment);

    // Add autoscaling
    const hpa = cluster.addManifest('HorizontalPodAutoscaler', {
      apiVersion: 'autoscaling/v2',
      kind: 'HorizontalPodAutoscaler',
      metadata: {
        name: 'microservice-hpa',
        namespace: 'app'
      },
      spec: {
        scaleTargetRef: {
          apiVersion: 'apps/v1',
          kind: 'Deployment',
          name: 'microservice'
        },
        minReplicas: 3,
        maxReplicas: 10,
        metrics: [
          {
            type: 'Resource',
            resource: {
              name: 'cpu',
              target: {
                type: 'Utilization',
                averageUtilization: 70
              }
            }
          }
        ]
      }
    });
    hpa.node.addDependency(deployment);

    // Output cluster endpoint and ARN
    new cdk.CfnOutput(this, 'ClusterEndpoint', {
      value: cluster.clusterEndpoint,
      description: 'EKS Cluster Endpoint'
    });

    new cdk.CfnOutput(this, 'ClusterArn', {
      value: cluster.clusterArn,
      description: 'EKS Cluster ARN'
    });

    new cdk.CfnOutput(this, 'ServiceUrl', {
      value: `http://${service.manifest.metadata.name}.${service.manifest.metadata.namespace}`,
      description: 'Microservice URL'
    });
  }
}