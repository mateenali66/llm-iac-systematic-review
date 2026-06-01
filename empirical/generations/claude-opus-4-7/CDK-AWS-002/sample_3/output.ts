import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as iam from 'aws-cdk-lib/aws-iam';
import { KubectlV30Layer } from '@aws-cdk/lambda-layer-kubectl-v30';
import { Construct } from 'constructs';

export interface EksFargateMicroserviceStackProps extends cdk.StackProps {
  readonly clusterName?: string;
  readonly namespaceName?: string;
  readonly appName?: string;
  readonly containerImage?: string;
  readonly containerPort?: number;
  readonly replicas?: number;
}

export class EksFargateMicroserviceStack extends cdk.Stack {
  public readonly cluster: eks.FargateCluster;
  public readonly vpc: ec2.Vpc;

  constructor(scope: Construct, id: string, props: EksFargateMicroserviceStackProps = {}) {
    super(scope, id, props);

    const clusterName = props.clusterName ?? 'eks-fargate-cluster';
    const namespaceName = props.namespaceName ?? 'app';
    const appName = props.appName ?? 'microservice';
    const containerImage = props.containerImage ?? 'public.ecr.aws/nginx/nginx:1.27';
    const containerPort = props.containerPort ?? 80;
    const replicas = props.replicas ?? 3;

    this.vpc = new ec2.Vpc(this, 'EksVpc', {
      maxAzs: 3,
      natGateways: 1,
      ipAddresses: ec2.IpAddresses.cidr('10.0.0.0/16'),
      subnetConfiguration: [
        { name: 'Public', subnetType: ec2.SubnetType.PUBLIC, cidrMask: 24 },
        { name: 'Private', subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS, cidrMask: 22 },
      ],
      enableDnsHostnames: true,
      enableDnsSupport: true,
    });

    cdk.Tags.of(this.vpc).add('kubernetes.io/cluster/' + clusterName, 'shared');
    this.vpc.publicSubnets.forEach((s) => cdk.Tags.of(s).add('kubernetes.io/role/elb', '1'));
    this.vpc.privateSubnets.forEach((s) => cdk.Tags.of(s).add('kubernetes.io/role/internal-elb', '1'));

    const clusterAdminRole = new iam.Role(this, 'ClusterAdminRole', {
      assumedBy: new iam.AccountRootPrincipal(),
      description: 'Admin role for managing the EKS cluster',
    });

    this.cluster = new eks.FargateCluster(this, 'FargateCluster', {
      clusterName,
      version: eks.KubernetesVersion.V1_30,
      kubectlLayer: new KubectlV30Layer(this, 'KubectlLayer'),
      vpc: this.vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }, { subnetType: ec2.SubnetType.PUBLIC }],
      mastersRole: clusterAdminRole,
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
        eks.ClusterLoggingTypes.CONTROLLER_MANAGER,
        eks.ClusterLoggingTypes.SCHEDULER,
      ],
    });

    this.cluster.addFargateProfile('AppFargateProfile', {
      selectors: [{ namespace: namespaceName }, { namespace: 'kube-system' }],
    });

    const albServiceAccount = this.cluster.addServiceAccount('AlbControllerSa', {
      name: 'aws-load-balancer-controller',
      namespace: 'kube-system',
    });

    const albPolicyStatements: iam.PolicyStatement[] = [
      new iam.PolicyStatement({
        actions: [
          'iam:CreateServiceLinkedRole',
          'ec2:DescribeAccountAttributes',
          'ec2:DescribeAddresses',
          'ec2:DescribeAvailabilityZones',
          'ec2:DescribeInternetGateways',
          'ec2:DescribeVpcs',
          'ec2:DescribeVpcPeeringConnections',
          'ec2:DescribeSubnets',
          'ec2:DescribeSecurityGroups',
          'ec2:DescribeInstances',
          'ec2:DescribeNetworkInterfaces',
          'ec2:DescribeTags',
          'ec2:GetCoipPoolUsage',
          'ec2:DescribeCoipPools',
          'elasticloadbalancing:DescribeLoadBalancers',
          'elasticloadbalancing:DescribeLoadBalancerAttributes',
          'elasticloadbalancing:DescribeListeners',
          'elasticloadbalancing:DescribeListenerCertificates',
          'elasticloadbalancing:DescribeSSLPolicies',
          'elasticloadbalancing:DescribeRules',
          'elasticloadbalancing:DescribeTargetGroups',
          'elasticloadbalancing:DescribeTargetGroupAttributes',
          'elasticloadbalancing:DescribeTargetHealth',
          'elasticloadbalancing:DescribeTags',
          'cognito-idp:DescribeUserPoolClient',