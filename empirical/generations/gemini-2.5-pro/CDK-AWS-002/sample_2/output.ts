import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import { KubectlV27Layer } from '@aws-cdk/lambda-layer-kubectl-v27';

export class EksFargateAlbStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'EksVpc', {
      maxAzs: 3,
      natGateways: 1,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          cidrMask: 24,
          name: 'private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
      ],
    });

    const cluster = new eks.FargateCluster(this, 'EksFargateCluster', {
      vpc,
      version: eks.KubernetesVersion.V1_27,
      clusterName: 'production-fargate-cluster',
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
      kubectlLayer: new KubectlV27Layer(this, 'KubectlLayer'),
      fargateProfiles: {
        AppFargateProfile: {
          selectors: [{ namespace: 'app' }]
        }
      }
    });

    const albController = new eks.AlbController(this, 'AlbController', {
      cluster: cluster,
      version: eks.AlbControllerVersion.V2_5_1,
    });

    const appNamespace = {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: { name: 'app' },
    };

    const appDeployment = {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'hello-kubernetes-deployment',
        namespace: 'app',
      },
      spec: {
        replicas: 2,
        selector: {
          matchLabels: { app: 'hello-kubernetes' },
        },
        template: {
          metadata: {
            labels: { app: 'hello-kubernetes' },
          },
          spec: {
            containers: [
              {
                name: 'hello-kubernetes',
                image: 'paulbouwer/hello-kubernetes:1.10',
                ports: [{ containerPort: 8080 }],
                resources: {
                  requests: {
                    cpu: '256m',
                    memory: '512Mi',
                  },
                  limits: {
                    cpu: '512m',
                    memory: '1024Mi',
                  },
                },
              },
            ],
          },
        },
      },
    };

    const