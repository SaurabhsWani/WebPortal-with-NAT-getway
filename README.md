# WebPortal-with-NAT-getway

Starting Setup:

1) Aws root/IAM(with all power) account Access key id and Secret Access key.

2) Key pair Created from aws console or from aws cli.

3) Install the AWS CLI, You can click to Download from official site.

4) Install Terraform, You can click to download suitable version for your pc.

Paste both .exe file in your environment variable path or create new environment variable path. Search environmental variable you will see below window, you can both .exe files in that path C:\Users\SSRJ\AppData\Local\program...

    "see Environmet_variable image"

Creat a new folder or directory where you want and save all the below file in that folder/directory as shown above.

Note: Before going to run any terraform file, first run the command "terraform init", after running this command terraform will download all plugin require for your code. As shown in image

    "see Init image"

If you run terraform code without terraform init command you will face error shown below

    "see Error image"

After initializing terraform, login your aws account from cli with some profile name(ssw is used in image) as shown in image. This profile name we must have to provide in the terraform code.

    "see login image"

Now here starts the main practical

To create the VPC here is code. You can change the cidr_block, assign ip range as you want, you can assign the range from there ip range

1) 10.0.0.0 – 10.255.255.255
2) 172.16.0.0 – 172.31.255.255
3) 192.168.0.0 – 192.168.255.255


  
    resource "aws_vpc" "sswvpc" {
    cidr_block       = "192.168.0.0/16"
    instance_tenancy = "default"
    enable_dns_hostnames = true
    tags = {
    Name = "Vpc_terraform"
    }  
    }

For creating the private and public subnet here is code.here you can change a availability_zone_id of your region, you have to assign 2 different availability_zone_id.


    
    //public subnet
      resource "aws_subnet" "sswsn1" {
       depends_on = [aws_vpc.sswvpc]
        vpc_id     = aws_vpc.sswvpc.id
        cidr_block = "192.168.0.0/24"
        availability_zone_id = "aps1-az1"
        map_public_ip_on_launch = true
        enable_dns_hostnames = true
        tags = {
          Name = "Public_Subnet_terraform"
        }
      }
    //private subnet
      resource "aws_subnet" "sswsn2" {
      depends_on = [aws_vpc.sswvpc]
        vpc_id     = aws_vpc.sswvpc.id
        cidr_block = "192.168.1.0/24"
        availability_zone_id = "aps1-az3"
        tags = {
          Name = "Private_Subnet_terraform"
        }
      }


To create internet getway


    //creating internet getway
    resource "aws_internet_gateway" "sswig" {
    depends_on = [aws_vpc.sswvpc]
      vpc_id = aws_vpc.sswvpc.id
      tags = {
        Name = "IG_terraform"
    }
    }


Updating the default routing table

    //updating default routing table
      resource "aws_default_route_table" "r" {
      depends_on  = [aws_internet_gateway.sswig,aws_vpc.sswvpc]
        default_route_table_id = aws_vpc.sswvpc.default_route_table_id
         route {
          cidr_block = "0.0.0.0/0"
          gateway_id = aws_internet_gateway.sswig.id
        }
        tags = {
          Name = "Rout_table_terraform"
      
      
      }
      }

Attaching the routing table to public subnet

    //routing association with subnet1 making it public
    resource "aws_route_table_association" "a" {
    depends_on  = [aws_default_route_table.r,aws_subnet.sswsn1]
      subnet_id      = aws_subnet.sswsn1.id
         route_table_id = aws_vpc.sswvpc.default_route_table_id
    }
    
      
Creating NAT getway with EIP, routing table, and associating it with subnet 2
    
        //creating EIP
    resource "aws_eip" "sswEIP" {
      vpc      = true
    }


    //creating NAT getway
    resource "aws_nat_gateway" "sswNAT" {
      allocation_id = aws_eip.sswEIP.id
      subnet_id = aws_subnet.sswsn1.id
      tags = {
        Name = "NAT Getway for private subnet"
      }
    }


    //creaig routing table
    resource "aws_route_table" "sswRT" {
    depends_on  = [aws_nat_gateway.sswNAT,aws_vpc.sswvpc]
      vpc_id = aws_vpc.sswvpc.id


      route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.sswNAT.id
      }
      tags = {
        Name = "RT_FOR_PRIVATE_SUBNET"
      }
    }


    //routing table association with subnet2 
    resource "aws_route_table_association" "b" {
    depends_on  = [aws_route_table.sswRT,aws_subnet.sswsn2]
      subnet_id      = aws_subnet.sswsn2.id
      route_table_id = aws_route_table.sswRT.id
    }

Here is the important part which is security group which plays important rule without it security is no that much strong.

      //creating security grp for bostion host 
      resource "aws_security_group" "mysecbh"{
      depends_on = [aws_vpc.sswvpc]
          name        = "bhteraasec"
          vpc_id      = aws_vpc.sswvpc.id
          ingress{
                 description = "For login to bostion host from anywhere"
                 from_port   = 22
                 to_port     = 22
                 protocol    = "TCP"
                 cidr_blocks = ["0.0.0.0/0"]
                 ipv6_cidr_blocks  = ["::/0"]
            }
          egress{
                 from_port   = 0
                      to_port     = 0
           protocol    = "-1"
           cidr_blocks = ["0.0.0.0/0"]
      }
    tags ={
           Name = "SG_Bostion_host_terraform"
      }
    }
    //creating security grp for WordPress 
    resource "aws_security_group" "mysecwp"{
    depends_on = [aws_vpc.sswvpc,aws_security_group.mysecbh]
        name        = "wpteraasec"
        vpc_id      = aws_vpc.sswvpc.id
        ingress{
               description = "For connecting to WordPress from outside world"
               from_port   = 80
               to_port     = 80
               protocol    = "TCP"
               cidr_blocks = ["0.0.0.0/0"]
               ipv6_cidr_blocks  = ["::/0"]
          }
        ingress{
               description = "Only bostion host can connect to WordPress using ssh"
               from_port   = 22
               to_port     = 22
               protocol    = "TCP"
               security_groups=[aws_security_group.mysecbh.id]
               ipv6_cidr_blocks  = ["::/0"]
          }
        ingress{
               description = "icmp from VPC"
               from_port   = -1
               to_port     = -1
               protocol    = "icmp"
               cidr_blocks = ["0.0.0.0/0"]
               ipv6_cidr_blocks =  ["::/0"]
          }
        egress{
               from_port   = 0
               to_port     = 0
               protocol    = "-1"
               cidr_blocks = ["0.0.0.0/0"]
               ipv6_cidr_blocks =  ["::/0"]
      }
        tags ={
               Name = "SG_WordPress_terraform"
          }
    }
    //creating security grp for MySql 

        resource "aws_security_group" "mysecms"{
        depends_on = [aws_vpc.sswvpc,aws_security_group.mysecwp]
        name        = "msteraasec"
        vpc_id      = aws_vpc.sswvpc.id
        ingress{
               description = "WordPress can connect to MySql"
               from_port   = 3306
               to_port     = 3306
               protocol    = "TCP"
               security_groups=[aws_security_group.mysecwp.id]
          }


        ingress{
               description = "Only web ping sql from public subnet"
               from_port   = -1
               to_port     = -1
               protocol    = "icmp"
               security_groups=[aws_security_group.mysecwp.id]
               ipv6_cidr_blocks=["::/0"]
          }
        ingress{
               description = "Only bostion host can connect to MySql using ssh"
               from_port   = 22
               to_port     = 22
               protocol    = "TCP"
               security_groups=[aws_security_group.mysecbh.id]
               ipv6_cidr_blocks  = ["::/0"]
          }
         egress{
               from_port   = 0
               to_port     = 0
               protocol    = "-1"
               cidr_blocks = ["0.0.0.0/0"]
               ipv6_cidr_blocks =  ["::/0"]
      }
        tags ={
               Name = "SG_MySql_terraform"
          }
    }

Launching EC2 instances of WordPress, MySql and bostion host. If you have your AMI of WordPress, MySql you can change AMI in this code, but you also change in last code where uploading key to bastion host instance. Also you can change instance_type which you want



      //creating WordPress OS
      resource "aws_instance" "wpmyins"{
      depends_on = [aws_security_group.mysecwp]
          ami     = "ami-0e9c43b5bc2603d9d" //enter ami/os image id if you want another os(now it is amazon linux)
          instance_type   ="t2.micro"
          vpc_security_group_ids =[aws_security_group.mysecwp.id]
          key_name    ="asdf"                //enter key_pair name you created at aws console
          subnet_id = aws_subnet.sswsn1.id
          tags ={
              Name = "WordPress_os_terraform"
            }
      }

    //creating MySql OS
    resource "aws_instance" "msmyins"{
    depends_on = [aws_security_group.mysecms]
        ami     = "ami-0eb6467b60a881234" //enter ami/os image id if you want another os(now it is amazon linux)
        instance_type   ="t2.micro"
        vpc_security_group_ids =[aws_security_group.mysecms.id]
        key_name    ="asdf"                //enter key_pair name you created at aws console
        subnet_id = aws_subnet.sswsn2.id
        tags ={
            Name = "MySql_os_terraform"
          }
    }

    //creating bostion host OS
    resource "aws_instance" "bhmyins"{
    depends_on = [aws_security_group.mysecbh]
        ami     = "ami-08706cb5f68222d09" //enter ami/os image id if you want another os(now it is amazon linux)
        instance_type   ="t2.micro"
        vpc_security_group_ids =[aws_security_group.mysecbh.id]
        key_name    ="asdf"                //enter key_pair name you created at aws console
        subnet_id = aws_subnet.sswsn1.id
        tags ={
            Name = "Bositon_Host_os_terraform"
          }
    }

Here is last part downloading IPs of instances and uploading the key on bostion host os.


    //downloading required IPs of all three OS
    resource "null_resource" "download_IP"{
        depends_on = [
        aws_instance.wpmyins,
        aws_instance.msmyins,
        aws_instance.bhmyins,
        ]
        provisioner "local-exec"{
              command = "echo WORDPRESS_Public_IP:${aws_instance.wpmyins.public_ip}-----WORDPRESS_Private_IP:${aws_instance.wpmyins.private_ip}-----Bositon_OS_Public_IP:${aws_instance.bhmyins.public_ip}-----MySql_Privat_IP:${aws_instance.msmyins.private_ip} > your_domain.txt "   //you will get your ip address in "your_domain.txt" file in directory where you run this code    
          } 
          }


//Uploading the Key pair (file_name.pem) to the bostion host


    resource "null_resource" "Uploading_key_on_bh_instance"{
        depends_on = [
        aws_instance.wpmyins,
        aws_instance.msmyins,
        aws_instance.bhmyins,
        ]
        provisioner "local-exec"{
              command = "scp -i C:/Users/SSRJ/Desktop/tera/ssw/asdf.pem C:/Users/SSRJ/Desktop/tera/ssw/asdf.pem  ec2-user@${aws_instance.bhmyins.public_ip}:~/"      
          }
      }

Example

    command = "scp -i Path_Of_Key_pair Path_Of_Uploading_Key_Pair  ec2-user@${aws_instance.bhmyins.public_ip}:~/"
    //for example 
    command = "scp -i C:/Users/SSRJ/Desktop/tera/ssw/asdf.pem C:/Users/SSRJ/Desktop/tera/ssw/asdf.pem  ec2-user@${aws_instance.bhmyins.public_ip}:~/"

In above command you have to change the path Path_Of_Key_pair Path_Of_Uploading_Key_Pair as shown in example above.

Now save all the code in file name as main.tf as shown below

    "see the main.tf file"
    "see structure image" to understand the complete environment

Run command "terraform apply -auto-approve" to create complete environment
Note: You have to enter yes while running the code in cmd as shown in image. This is for the uploading key on bostion host.

    "see the main.tf image"

And the setup is ready, you can see from the console of aws

    "see 3 EC2 Instances image"
    "see 3 Security Groups image"
    "see VPC image"
    "see 2 Subnets image"
    "see Internet Getway image"
    "see Routing table image"
    "see Routing table new image"
    "see NAT image"
    "see EIP image"

You will get the IPs required for the connection to instances. You can see this in folder or path where you run the code. As shown in image.

    "see your_domain image"

Now it is time to create database and user in MySql and install the WordPress, to create database we have to connect to bostion host os using ssh or putty. Here i connected to bostion host using putty.

All the entered command in below images are given below, here while creating user you have to enter the Private_ip address of the WordPress which you get in the file shown above name as your_domain.txt


    ls                    //you will see uploades key by this command
    sudo -su root 
    ssh -l ubuntu 192.168.1.15 -i asdf.pem   //to login to MySql os
    sudo -su root 
    mysql -uroot -p;              //To enter in MySql 
    CREATE DATABASE ssw_wp;       //To create database
    use ssw_wp;                   //To change or select database
    CREATE USER 'ssw_usrs'@'192.168.0.127' IDENTIFIED BY 'sswpass';  //creating user with password=sswpass
    GRANT ALL PRIVILEGES ON ssw_wp  TO 'ssw_usrs'@'192.168.0.127';
    //Greanting all privileges to user
    GRANT ALL PRIVILEGES ON ssw_wp.*  TO 'ssw_usrs'@'192.168.0.127';
    //Greanting all privileges to user


    "see putty1 image"
    "see putty2 image"
    "see putty3 image"
    
we can ping to the google as we attached the nat getway to private subnet

    "see ping google 1 image"
    "see google ping 2 image"
Now the database and user is created so use public ip of the WordPress to connect to website. As shown in image

    "see wp1 image"
    "see wp2 image"
    "see wp3 image"
    "see wp4 image"
    "see wp5 image"
Finally here is complete setup is ready!
If you want to delete complete setup run command "terraform destroy -auto-approve" and all setup will be deleted

    "see delete (1) image"
    "see delete (2) image"

Finally here is complete setup is ready! So finally the complete architecture of Launching web portal on aws Using Terraform is completed from start to end or creating to deletion.
