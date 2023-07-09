terraform {
    required_providers {
    oci = {
        source = "oracle/oci"
        version = ">=4.67.3"
        }
    }
    required_version = ">= 1.0.0"
}


#provider block
provider "oci" {
    tenancy_ocid = var.tenancy_ocid
    user_ocid = var.user_ocid
    fingerprint = var.fingerprint
    private_key_path = var.private_key_path
    region = var.region
}

#create a vcn
resource "oci_core_vcn" "ter_vcn" {
    compartment_id = var.compartment_id
    display_name = "terraform-vcn"
    cidr_blocks = ["10.0.0.0/16"]
}

#create a subnet in that vcn
resource "oci_core_subnet" "ter_subnet" {
    compartment_id = var.compartment_id
    display_name = "terraform-subnet"
    cidr_block = "10.0.0.0/24"
    vcn_id = oci_core_vcn.ter_vcn.id
    prohibit_public_ip_on_vnic = false
    route_table_id = oci_core_route_table.ter_rt.id
}

#create an internet gateway to that vcn
resource "oci_core_internet_gateway" "ter_igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.ter_vcn.id
  display_name   = "my-igw"
}

#create a route table to that vcn
resource "oci_core_route_table" "ter_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.ter_vcn.id
  display_name   = "my-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.ter_igw.id
  }
}

#create a security list to that vcn
resource "oci_core_security_list" "my_security_list" {
    compartment_id = var.compartment_id
    vcn_id         = oci_core_vcn.ter_vcn.id
    display_name   = "ter-sl"

    ingress_security_rules {
        protocol = "6"
        source = "0.0.0.0/0"
        tcp_options {
            max = 80
            min = 80
        }
        description = "Allow HTTP traffic from anywhere"
    }
    ingress_security_rules {
        protocol = "6"
        source = "0.0.0.0/0"
        tcp_options {
            min = 443
            max = 443
        }
        description = "Allow HTTPS traffic from anywhere"
    }
}

#create a compute instance
resource "oci_core_instance" "my-server" {
    availability_domain = "TuBN:AP-HYDERABAD-1-AD-1"
    compartment_id = var.compartment_id
    shape = var.instance_shape
    display_name = "terraform-instance"

   metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("./userdata"))
  }

    shape_config {
        ocpus = 1
        memory_in_gbs = 1
    }

    create_vnic_details {
        subnet_id                 = oci_core_subnet.ter_subnet.id
        display_name              = "PrimaryVNIC"
        assign_public_ip          = true
        assign_private_dns_record = true
    }

    source_details {
        source_type = "image"
        source_id = var.image_id
    }
}

#output the public ip of the instance
output "public_ip" {
    value = oci_core_instance.my-server.public_ip
}
