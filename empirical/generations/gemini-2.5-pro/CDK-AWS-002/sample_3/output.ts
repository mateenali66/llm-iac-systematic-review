import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';

export class EksFargateAlbStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'EksVpc', {
      maxAzs: 3,
      natGateways: 1,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: 'public-subnet',
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          cidrMask: 24,
          name: 'private-subnet',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
      ],
    });

    const cluster = new eks.FargateCluster(this, 'EksFargateCluster', {
      vpc,
      version: eks.KubernetesVersion.V1_28,
      clusterName: `fargate-cluster-${this.region}`,
      albController: {
        version: eks.AlbControllerVersion.V2_6_2,
      },
      outputClusterName: true,
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
    });

    const appNamespace = 'my-app';
    const appNamespaceManifest = {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: {
        name: appNamespace,
      },
    };

    cluster.addManifest('AppNamespace', appNamespaceManifest);

    const appLabels = { app: 'hello-kubernetes' };

    const deployment = {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'hello-kubernetes-deployment',
        namespace: appNamespace,
      },
      spec: {
        replicas: 2,
        selector: {
          matchLabels: appLabels,
        },
        template: {
          metadata: {
            labels: appLabels,
          },
          spec: {
            containers: [
              {