//connection with aws

provider "aws"{ 
    region     = "ap-south-1"
    profile    = "ssw"    //Enter your profile name which set at cli login
  }




//creating vpc  
resource "aws_vpc" "sswvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "Vpc_terraform"
  }
}




//creating subnet
resource "aws_subnet" "sswsn1" {
depends_on = [aws_vpc.sswvpc]
  vpc_id     = aws_vpc.sswvpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone_id = "aps1-az1"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public_Subnet_terraform"
  }
}

resource "aws_subnet" "sswsn2" {
depends_on = [aws_vpc.sswvpc]
  vpc_id     = aws_vpc.sswvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone_id = "aps1-az3"
  tags = {
    Name = "Private_Subnet_terraform"
  }
}




//creating internet getway
resource "aws_internet_gateway" "sswig" {
depends_on = [aws_vpc.sswvpc]
  vpc_id = aws_vpc.sswvpc.id
  tags = {
    Name = "IG_terraform"
  }
}




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




//routing association with subnet1 making it public
resource "aws_route_table_association" "a" {
depends_on  = [aws_default_route_table.r,aws_subnet.sswsn1]
  subnet_id      = aws_subnet.sswsn1.id
  route_table_id = aws_vpc.sswvpc.default_route_table_id
}

//-------------------------------------------------------------------
resource "aws_eip" "sswEIP" {
  vpc      = true
}

resource "aws_nat_gateway" "sswNAT" {
  allocation_id = aws_eip.sswEIP.id
  subnet_id = aws_subnet.sswsn1.id
  tags = {
    Name = "NAT Getway for private subnet"
  }
}

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
//routing association with subnet2 making it able to connect public world but public world cannot connect to it 

resource "aws_route_table_association" "b" {
depends_on  = [aws_route_table.sswRT,aws_subnet.sswsn2]
  subnet_id      = aws_subnet.sswsn2.id
  route_table_id = aws_route_table.sswRT.id
}

//-------------------------------------------------------------------


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




  
