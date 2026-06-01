import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import { KubectlV31Layer } from '@aws-cdk/lambda-layer-kubectl-v31';

export interface EksFargateMicroserviceStackProps extends cdk.StackProps {
  readonly clusterName?: string;
  readonly containerImage?: string;
  readonly containerPort?: number;
  readonly replicas?: number;
  readonly namespace?: string;
}

export class EksFargateMicroserviceStack extends cdk.Stack {
  public readonly cluster: eks.FargateCluster;

  constructor(scope: Construct, id: string, props: EksFargateMicroserviceStackProps = {}) {
    super(scope, id, props);

    const clusterName = props.clusterName ?? 'fargate-microservice-cluster';
    const containerImage = props.containerImage ?? 'public.ecr.aws/nginx/nginx:1.27-alpine';
    const containerPort = props.containerPort ?? 80;
    const replicas = props.replicas ?? 2;
    const namespace = props.namespace ?? 'app';
    const appName = 'microservice';

    const vpc = new ec2.Vpc(this, 'ClusterVpc', {
      maxAzs: 3,
      natGateways: 1,
      subnetConfiguration: [
        { name: 'public', subnetType: ec2.SubnetType.PUBLIC, cidrMask: 24 },
        { name: 'private', subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS, cidrMask: 22 },
      ],
      flowLogs: {
        cwl: {
          destination: ec2.FlowLogDestination.toCloudWatchLogs(
            new logs.LogGroup(this, 'VpcFlowLogs', {
              retention: logs.RetentionDays.ONE_MONTH,
              removalPolicy: cdk.RemovalPolicy.DESTROY,
            }),
          ),
          trafficType: ec2.FlowLogTrafficType.REJECT,
        },
      },
    });

    const masterRole = new iam.Role(this, 'EksAdminRole', {
      assumedBy: new iam.AccountRootPrincipal(),
      description: 'Admin role for EKS cluster access',
    });

    const cluster = new eks.FargateCluster(this, 'FargateCluster', {
      version: eks.KubernetesVersion.V1_31,
      kubectlLayer: new KubectlV31Layer(this, 'KubectlLayer'),
      clusterName,
      vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
      mastersRole: masterRole,
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
        eks.ClusterLoggingTypes.CONTROLLER_MANAGER,
        eks.ClusterLoggingTypes.SCHEDULER,
      ],
    });

    this.cluster = cluster;

    cluster.addFargateProfile('AppProfile', {
      selectors: [{ namespace }, { namespace: 'kube-system' }],
    });

    const appNamespace = cluster.addManifest('AppNamespace', {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: { name: namespace },
    });

    const albServiceAccount = cluster.addServiceAccount('AlbControllerSA', {
      name: 'aws-load-balancer-controller',
      namespace: 'kube-system',
    });

    const albPolicyDoc = iam.PolicyDocument.fromJson({
      Version: '2012-10-17',
      Statement: [
        { Effect: 'Allow', Action: ['iam:CreateServiceLinkedRole'], Resource: '*',
          Condition: { StringEquals: { 'iam:AWSServiceName': 'elasticloadbalancing.amazonaws.com' } } },
        { Effect: 'Allow', Action: [
          'ec2:DescribeAccountAttributes','ec2:DescribeAddresses','ec2:DescribeAvailabilityZones',
          'ec2:DescribeInternetGateways','ec2:DescribeVpcs','ec2:DescribeVpcPeeringConnections',
          'ec2:DescribeSubnets','ec2:DescribeSecurityGroups','ec2:DescribeInstances',
          'ec2:DescribeNetworkInterfaces','ec2:DescribeTags','ec2:GetCoipPoolUsage',
          'ec2:DescribeCoipPools','elasticloadbalancing:DescribeLoadBalancers',
          'elasticloadbalancing:DescribeLoadBalancerAttributes','elasticloadbalancing:DescribeListeners',
          'elasticloadbalancing:DescribeListenerCertificates','elasticloadbalancing:DescribeSSLPolicies',
          'elasticloadbalancing:DescribeRules','elasticloadbalancing:DescribeTargetGroups',
          'elasticloadbalancing:DescribeTargetGroupAttributes','elasticloadbalancing:DescribeTargetHealth',
          'elasticloadbalancing:DescribeTags','elasticloadbalancing:Desc