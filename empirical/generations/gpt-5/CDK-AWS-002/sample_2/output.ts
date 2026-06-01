import * as cdk from 'aws-cdk-lib';
import { Stack, StackProps, CfnOutput, RemovalPolicy, Tags } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as kms from 'aws-cdk-lib/aws-kms';

class EksFargateAlbStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'Vpc', {
      maxAzs: 2,
      natGateways: 2,
      subnetConfiguration: [
        { name: 'Public', subnetType: ec2.SubnetType.PUBLIC },
        { name: 'Private', subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
      ],
    });

    const secretsKey = new kms.Key(this, 'EksSecretsKey', {
      enableKeyRotation: true,
      removalPolicy: RemovalPolicy.RETAIN,
    });

    const cluster = new eks.Cluster(this, 'EksFargateCluster', {
      version: eks.KubernetesVersion.V1_29,
      vpc,
      defaultCapacity: 0,
      secretsEncryptionKey: secretsKey,
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
    });

    for (const subnet of vpc.publicSubnets) {
      Tags.of(subnet).add('kubernetes.io/role/elb', '1');
      Tags.of(subnet).add(`kubernetes.io/cluster/${cluster.clusterName}`, 'shared');
    }
    for (const subnet of vpc.privateSubnets) {
      Tags.of(subnet).add('kubernetes.io/role/internal-elb', '1');
      Tags.of(subnet).add(`kubernetes.io/cluster/${cluster.clusterName}`, 'shared');
    }

    const albControllerSa = cluster.addServiceAccount('AwsLoadBalancerControllerSA', {
      name: 'aws-load-balancer-controller',
      namespace: 'kube-system',
    });
    albControllerSa.role.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName('AWSLoadBalancerControllerIAMPolicy')
    );

    const albController = cluster.addHelmChart('AWSLoadBalancerController', {
      chart: 'aws-load-balancer-controller',
      repository: 'https://aws.github.io/eks-charts',
      namespace: 'kube-system',
      release: 'aws-load-balancer-controller',
      version: '1.7.2',
      values: {
        clusterName: cluster.clusterName,
        region: Stack.of(this).region,
        vpcId: vpc.vpcId,
        serviceAccount: {
          create: false,
          name: albControllerSa.serviceAccountName,
        },
      },
    });
    albController.node.addDependency(albControllerSa);

    cluster.addFargateProfile('FargateKubeSystem', {
      selectors: [
        {
          namespace: 'kube-system',
          labels: { 'k8s-app': 'kube-dns' },
        },
      ],
    });

    cluster.addFargateProfile('FargateApp', {
      selectors: [
        {
          namespace: 'app',
        },
      ],
    });

    const appNs = cluster.addManifest('AppNamespace', {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: {
        name: 'app',
        labels: {
          'app.kubernetes.io/name': 'app',
        },
      },
    });

    const appLabels = { app: 'web' };

    const appDeployment = cluster.addManifest('AppDeployment', {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: { name: 'web', namespace: 'app' },
      spec: {
        replicas: 2,
        selector: { matchLabels: appLabels },
        template: {
          metadata: { labels: appLabels },
          spec: {
            terminationGracePeriodSeconds: 30,
            containers: [
              {
                name: 'nginx',
                image: 'public.ecr.aws/nginx/nginx:stable',
                ports: [{ containerPort: 80 }],
                resources: {
                  requests: { cpu: '100m', memory: '128Mi' },
                  limits: { cpu: '500m', memory: '256Mi' },
                },
                livenessProbe: {
                  httpGet: { path: '/', port: 80 },
                  initialDelaySeconds: 10,
                  periodSeconds: 10,
                },
                readinessProbe: {
                  httpGet: { path: '/', port: 80 },
                  initialDelaySeconds: 5,
                  periodSeconds: 5,
                },
              },
            ],
          },
        },
      },
    });
    appDeployment.node.addDependency(appNs);

    const appService = cluster.addManifest('AppService', {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: { name: 'web-svc', namespace: 'app' },
      spec: {
        type: 'ClusterIP',
        ports: [{ port: 80, targetPort: 80 }],
        selector: appLabels,
      },
    });
    appService.node.addDependency(appDeployment);

    const appIngress = cluster.addManifest('AppIngress', {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'Ingress',
      metadata: {
        name: 'web-ingress',
        namespace: 'app',
        annotations: {
          'kubernetes.io/ingress.class': 'alb',
          'alb.ingress.kubernetes.io/scheme': 'internet-facing',
          'alb.ingress.kubernetes.io/target-type': 'ip',
          'alb.ingress.kubernetes.io/listen-ports': '[{"HTTP":80}]',
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
                      name: 'web-svc',
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
    appIngress.node.addDependency(appService);
    appIngress.node.addDependency(albController);

    new CfnOutput(this, 'ClusterName', { value: cluster.clusterName });
    new CfnOutput(this, 'ClusterArn', { value: cluster.clusterArn });
    new CfnOutput(this, 'VpcId', { value: vpc.vpcId });
  }
}

const app = new cdk.App();
new EksFargateAlbStack(app, 'EksFargateAlbStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
});