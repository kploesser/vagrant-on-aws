Labs: Vagrant with AWS
======================

Vagrant is a great way to spin up and destroy compute and storage resources when testing and demonstrating development snapshots.

But what if you need specialised hardware or appliances that exceed the physical resources of your local environment.

Simply move things to the cloud! And here is how.

Motivation
----------

The client sprint review date is set. All stakeholders are dialled in. You are ready to go and ... nothing happens.

As often in the software application development process, minor changes in (networking or infrastructure) configuration can lead to dramatic impact at the system level.

This is infamously known as the "it works on my machine" problem.

So rather than risking high profile client meetings, use infrastructure virtualisation to make sure that development snapshots are tested against the final configuration of the client environment.

Basic Concepts
--------------

### Boxes

Boxes are Vagrant's version of a machine image or AMI. They are community-sourced or derived from official cloud image builds.

You can search for available boxes using this URL.

```
https://app.vagrantup.com/boxes/search
```

For example, if you want Amazon Linux compatible boxes, select a Vagrant CentOS image.

```
https://app.vagrantup.com/centos/boxes/7
```

Note that boxes are created for specific providers. This limits your choice if your provider/box combination is not available.

### Plugins

Plugins extend the core functionality of Vagrant and include extensions such as AWS and proxy support.

You can search for plugins using this URL (not provided by the team behind Vagrant).

```
http://vagrant-lists.github.io/plugins.html
```

### Providers

Vagrant interfaces with a hypervisor such as VirtualBox, a concept it calls provider.

You can work with multiple providers such as VirtualBox, VMWare, Hyper-V, and Docker.

Note that boxes are provider-specific. If your box of choice is not available in the public Vagrant portal, you may need to create your own machine image.

```
https://www.vagrantup.com/docs/providers/
```

### Provisioning

Finally, provisioning automatically installs software and applies configuration changes on the guest OS.

For simple projects and testing your provisioning scripts, you can use the Vagrant shell provisioner.

For more advanced use cases, consider using a tool such as Chef.

```
https://www.vagrantup.com/docs/provisioning/
```

Basic Security Configuration
----------------------------

### Creating a Vagrant security group

Allow SSH and (if required) HTTP. Launching Vagrant-created resources into their own security group give you an additional level of control.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+01+01.png)

### Creating a Vagrant user

It is good practice to create a separate user with separate credentials and access keys for your Vagrant experiments.

Never use your AWS root credentials.

In particular, protect any AWS access keys and keypairs you may generate from accidental sharing via version control.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+01+02.png)

### Keeping your AWS access keys and keypairs safe

Never disclose AWS access keys and keypairs in plain text in your `Vagrantfile`. Always use environment variables instead.

```
# Read AWS authentication information from environment variables
aws.access_key_id = ENV['AWS_ACCESS_KEY_ID']
aws.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
```

Setting Up Local Test Environment
---------------------------------

Select the right guest operating system and version from the Hashicorp catalogue.

Make sure you aim for what is equivalent to your target environment (i.e., dev/prod parity).

Initialise your Vagrant project.

```
$ vagrant init centos/7
```

Edit the Vagrantfile and add the following to enable port forwarding and folder synchronisation.

```
Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  config.vm.provision :shell, path: "bootstrap.sh"
  config.vm.network :forwarded_port, guest: 80, host: 4000
  config.vm.synced_folder ".", "/vagrant", type: "rsync"
end
```

See the `Vagrantfile.local` file in this Git repository for more details.

Provisioning and Boot
---------------------

Automatically spin up and provision a virtual machine using the vagrant up command.

Make sure to execute this command in your project root folder.

```
$ vagrant up
```

If you have not downloaded a version of the CentOS box before, Vagrant will now attempt to do so.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+02+01.png)

If all goes well, the shell provisioner script will install and start Apache.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+02+02.png)

You can now test your installation by bringing up `http://localhost:4000` in your web browser.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+02+03.png)

After testing your environment, make sure to destroy the Vagrant machine to release compute and storage resources.

```
$ vagrant destroy --force
```

Setting Up Remote Test Environment
----------------------------------

Before proceeding, install the Vagrant AWS plugin.

```
$ vagrant plugin install vagrant-aws
```

You can add a require statement in your `Vagrantfile` to make sure the plug in is installed before provisioning.

```
# Require the AWS provider plugin
require 'vagrant-aws'
```

You also need to download the AWS dummy box.

```
$ vagrant box add aws-dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box
```

Before you can `vagrant up` into your environment, you need to make a few changes in your `Vagrantfile`.

-	Set the AWS access key and secret access key environment variables.
-	Specify the AWS region, instance type, security group, and AMI.
-	Override the automatic SSH login in Vagrant to use an EC2 keypair.

See the `Vagrantfile.aws` file for details.

Note that AMI identifiers change between region. Here is how you look up yours.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+03+01.png)

Your `Vagrantfile` should now have the following entries.

```
# Require the AWS provider plugin
require 'vagrant-aws'

Vagrant.configure('2') do |config|

  # Use dummy AWS box
  config.vm.box = 'dummy'
  config.vm.provision :shell, path: "bootstrap.sh"
  config.vm.synced_folder ".", "/vagrant", type: "rsync"

  # Specify AWS provider configuration
  config.vm.provider 'aws' do |aws, override|
    # Read AWS authentication information from environment variables
    aws.access_key_id = ENV['AWS_ACCESS_KEY_ID']
    aws.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']

    # Specify SSH keypair to use
    aws.keypair_name = 'vagrant-keypair'

    # Specify region, AMI ID, and security group(s)
    aws.region = 'ap-southeast-2'
    aws.ami = 'ami-8536d6e7'
    aws.instance_type= 't2.micro'
    aws.security_groups = ['vagrant']

    # Specify username and private key path
    override.ssh.username = 'ec2-user'
    override.ssh.private_key_path = 'vagrant-keypair.pem'

  end
end
```

Note that you may be experiencing issues during the provisioning stage when `rsync` folder synchronisation is NOT enabled.

Provisioning and Boot
---------------------

Use the same command as before to boot and provision (but now directly in EC2 rather than your local machine).

```
$ vagrant up
```

Vagrant will now attempt to spin up a new EC2 instance according to the parameters you provided.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+04+01.png)

Note that any network settings in the `Vagrantfile` are silently ignored.

When the EC2 instance is ready, Vagrant will attempt to provision the machine.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+04+02.png)

You can log into the EC2 instance as normal via the vagrant ssh command.

```
$ vagrant ssh
```

This will bring you to the Amazon Linux prompt on your newly provisioned EC2 instance.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+04+03.png)

Test your provisioned EC2 instance by bringing up the test web site.

First, identify the public EC2 instance IP by logging into the AWS console.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+04+04.png)

You can now test your Apache web server in the cloud by typing in the public IP.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+04+05.png)

Do not forget to destroy the EC2 resources you created to avoid incurring unnecessary charges.

```
$ vagrant destroy --force
```

You can follow the progress of shutting down EC2 resources in the AWS console.

![Screenshot](https://github.com/kploesser/vagrant-on-aws/raw/master/images/image+04+06.png)

Additional Topics
-----------------

### Multi-machine provisioning

Vagrant allows provisioning multiple machines to model multi-server topologies such as a separation of web, application, and database servers.

This is particularly useful if you want to test multi-tier web applications.

```
https://www.vagrantup.com/docs/multi-machine/
```

### Exporting Vagrant boxes as AMI

In case Vagrant does not support your specific guest OS requirement or no suitable AMI is available on AWS, you can use the Packer tool to create your own.

```
https://www.packer.io/
```

Packer allows you to build your own AMI and turn it into a Vagrant box via post-processors.

Alternative Architecture Options
--------------------------------

While Vagrant is great for spinning up and destroying compute and storage resources for test or development environments, it is generally not recommended for production environments.

This is the domain of tools like Terraform. Terraform allows you to "write, plan, and create infrastructure as code" across different platforms. This includes AWS but also Microsoft Azure. Unlike Vagrant, Terraform provides first-class citizen support for creating, provisioning, and managing more complex architectures.

You can version control Terraform artefacts used to create infrastructure as code similar to how you would version control application code that runs on this infrastructure.

So if you consider going down the infrastructure as code route for your production environment, give Terraform a go.

Cost Impact
-----------

You can control the EC2 instance type and other EC2 resources created via Vagrant such as Elastic Load Balancers.

Make sure you destroy all provisioned resources using the `vagrant destroy --force` command to avoid incurring unnecessary charges.

Other cost optimisation strategies include right-sizing the EBS storage type used by your EC2 instance via the `aws.block_device_mapping` property.

Use AWS tags via the `aws.tags` property for adequate reporting of Vagrant consumption of EC2 resources and billing.

All properties are properties of the `Vagrantfile` defined in accordance with the Vagrant AWS plugin documentation.

References
----------

Vagrant https://www.vagrantup.com/

Vagrant AWS Plugins https://github.com/mitchellh/vagrant-aws

Amazon Linux AMI https://aws.amazon.com/amazon-linux-ami/

CentOS Vagrant images https://seven.centos.org/2017/09/updated-centos-vagrant-images-available-v1708-01/

Terraform https://www.terraform.io/
