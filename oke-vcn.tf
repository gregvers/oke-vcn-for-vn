variable "compartment_ocid" {}
variable "region" {}

provider "oci" {
  region = "${var.region}"
}

resource "oci_core_vcn" "oke_vcn" {
	cidr_block = "10.0.0.0/16"
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_vcn"
	dns_label = "okecluster"
}

resource "oci_core_internet_gateway" "oke_igw" {
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_igw"
	enabled = "true"
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_nat_gateway" "oke_natgw" {
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_natgw"
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_service_gateway" "oke_svcgw" {
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_svcgw"
	services {
		#service_id = "ocid1.service.oc1.iad.aaaaaaaam4zfmy2rjue6fmglumm3czgisxzrnvrwqeodtztg7hwa272mlfna"
		service_id = data.oci_core_services.all_oci_services.services[0].id
	}
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
  #count = var.create_service_gateway == true ? 1 : 0
}

resource "oci_core_subnet" "oke_pod_private_subnet" {
        cidr_block = "10.0.30.0/24"
        compartment_id = "${var.compartment_ocid}"
        display_name = "oke_pod_private_subnet"
        prohibit_public_ip_on_vnic = "true"
        route_table_id = "${oci_core_route_table.oke_private_routetable.id}"
        security_list_ids = ["${oci_core_security_list.oke_pod_seclist.id}"]
        vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_subnet" "oke_svclb_public_subnet" {
	cidr_block = "10.0.21.0/24"
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_svclb_public_subnet"
	prohibit_public_ip_on_vnic = "false"
	route_table_id = "${oci_core_route_table.oke_public_routetable.id}"
	security_list_ids = ["${oci_core_security_list.oke_svclb_seclist.id}"]
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_subnet" "oke_node_private_subnet" {
	cidr_block = "10.0.10.0/24"
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_node_private_subnet"
	prohibit_public_ip_on_vnic = "true"
	route_table_id = "${oci_core_route_table.oke_private_routetable.id}"
	security_list_ids = ["${oci_core_security_list.oke_node_seclist.id}"]
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_subnet" "oke_k8sApiEndpoint_public_subnet" {
	cidr_block = "10.0.1.0/28"
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_k8sApiEndpoint_public_subnet"
	prohibit_public_ip_on_vnic = "false"
	route_table_id = "${oci_core_route_table.oke_public_routetable.id}"
	security_list_ids = ["${oci_core_security_list.oke_k8sApiEndpoint_seclist.id}"]
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_subnet" "oke_bastion_private_subnet" {
	cidr_block = "10.0.0.16/28"
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_bastion_private_subnet"
	prohibit_public_ip_on_vnic = "true"
	route_table_id = "${oci_core_route_table.oke_private_routetable.id}"
	security_list_ids = ["${oci_core_security_list.oke_bastion_seclist.id}"]
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_route_table" "oke_private_routetable" {
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_private_routetable"
	route_rules {
		description = "traffic to the internet"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		network_entity_id = "${oci_core_nat_gateway.oke_natgw.id}"
	}
	route_rules {
		description = "traffic to OCI services"
		destination = data.oci_core_services.all_oci_services.services[0].cidr_block
		destination_type = "SERVICE_CIDR_BLOCK"
		network_entity_id = "${oci_core_service_gateway.oke_svcgw.id}"
	}
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_route_table" "oke_public_routetable" {
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_public_routetable"
	route_rules {
		description = "traffic to/from internet"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		network_entity_id = "${oci_core_internet_gateway.oke_igw.id}"
	}
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_security_list" "oke_pod_seclist" {
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_pod_seclist"
	egress_security_rules {
		description = "Allow pods to communicate with anything"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		protocol = "all"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Allow service LB to communicate with pods"
		protocol = "all"
		source = "10.0.21.0/24"
		stateless = "false"
	}
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_security_list" "oke_svclb_seclist" {
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_svclb_seclist"
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	egress_security_rules {
		description = "Allow service LB to communicate with pods"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		protocol = "all"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Allow TCP/80 fron Internet to service LB"
		protocol = "6"
		source = "0.0.0.0/0"
		stateless = "false"
		tcp_options {
            min = 80
            max = 80
		}
	}
	ingress_security_rules {
		description = "Allow TCP/443 fron Internet to service LB"
		protocol = "6"
		source = "0.0.0.0/0"
		stateless = "false"
		tcp_options {
            min = 443
            max = 443
		}
	}
	ingress_security_rules {
		description = "Allow TCP/8080 fron Internet to service LB"
		protocol = "6"
		source = "0.0.0.0/0"
		stateless = "false"
		tcp_options {
            min = 8080
            max = 8080
		}
	}
}

resource "oci_core_security_list" "oke_node_seclist" {
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_node_seclist"
	egress_security_rules {
		description = "Allow nodes to communicate with anything"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		protocol = "all"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Allow pods on one worker node to communicate with pods on other worker nodes (private subnet)"
		protocol = "all"
		source = "10.0.10.0/24"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Path discovery from cluster control plane to worker nodes (private subnet)"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		source = "10.0.0.0/28"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Allow TCP traffic from cluster control plane"
		protocol = "6"
		source = "10.0.1.0/28"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Allow traffic from load balancers to worker nodes"
		protocol = "6"
		source = "10.0.20.0/24"
		stateless = "false"
		tcp_options {
            min = 30000
            max = 32767
		}
	}
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_security_list" "oke_k8sApiEndpoint_seclist" {
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_k8sApiEndpoint_seclist"
	egress_security_rules {
		description = "Allow cluster control plane to communicate with OKE"
		destination = data.oci_core_services.all_oci_services.services[0].cidr_block
		destination_type = "SERVICE_CIDR_BLOCK"
		protocol = "6"
		stateless = "false"
	}
	egress_security_rules {
		description = "Allow TCP traffic to worker nodes (private subnet)"
		destination = "10.0.10.0/24"
		destination_type = "CIDR_BLOCK"
		protocol = "all"
		stateless = "false"
	}
	egress_security_rules {
		description = "Allow TCP traffic to worker nodes (public subnet)"
		destination = "10.0.11.0/24"
		destination_type = "CIDR_BLOCK"
		protocol = "all"
		stateless = "false"
	}
	egress_security_rules {
		description = "Path discovery from cluster control plane to worker nodes (private subnet)"
		destination = "10.0.10.0/24"
		destination_type = "CIDR_BLOCK"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		stateless = "false"
	}
	egress_security_rules {
		description = "Path discovery from cluster control plane to worker nodes (public subnet)"
		destination = "10.0.11.0/24"
		destination_type = "CIDR_BLOCK"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Allow bastion to access the Kubernetes API endpoint"
		protocol = "6"
		source = "10.0.0.16/28"
		stateless = "false"
		tcp_options {
            max = 6443
            min = 6443
		}
	}
	ingress_security_rules {
		description = "Allow pods to access the API server"
		protocol = "6"
		source = "10.0.30.0/24"
		stateless = "false"
		tcp_options {
            max = 6443
            min = 6443
		}
	}
	ingress_security_rules {
		description = "Allow worker nodes to Kubernetes API endpoint communication (private subnet)"
		protocol = "6"
		source = "10.0.10.0/24"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Kubernetes worker to Kubernetes API endpoint communication (public subnet)"
		protocol = "6"
		source = "10.0.11.0/24"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Path discovery from worker nodes (private subnet) to cluster control plane"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		source = "10.0.10.0/24"
		stateless = "false"
	}
	ingress_security_rules {
		description = "Path discovery from worker nodes (public subnet) to cluster control plane"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		source = "10.0.11.0/24"
		stateless = "false"
	}
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_core_security_list" "oke_bastion_seclist" {
	compartment_id = "${var.compartment_ocid}"
	display_name = "oke_bastion_seclist"
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	egress_security_rules {
		description = "Allow bastion to access the cluster Kubernetes API endpoint (private subnet)"
		destination = "10.0.0.0/28"
		destination_type = "CIDR_BLOCK"
		protocol = "6"
		stateless = "false"
		tcp_options {
            max = 6443
            min = 6443
		}
	}
	egress_security_rules {
		description = "Allow bastion to access the cluster Kubernetes API endpoint (public subnet)"
		destination = "10.0.1.0/28"
		destination_type = "CIDR_BLOCK"
		protocol = "6"
		stateless = "false"
		tcp_options {
            max = 6443
            min = 6443
		}
	}
	egress_security_rules {
		description = "Allow bastion to communicate with cluster worker nodes (private subnet)"
		destination = "10.0.10.0/24"
		destination_type = "CIDR_BLOCK"
		protocol = "6"
		stateless = "false"
		tcp_options {
            max = 22
            min = 22
		}
	}
}

resource "oci_core_network_security_group" "oke_svclb_nsg" {
    compartment_id = "${var.compartment_ocid}"
    vcn_id = "${oci_core_vcn.oke_vcn.id}"
	display_name = "oke_svclb_nsg"
}

resource "oci_core_network_security_group" "oke_k8sApiEndpoint_nsg" {
    compartment_id = "${var.compartment_ocid}"
    vcn_id = "${oci_core_vcn.oke_vcn.id}"
	display_name = "oke_k8sApiEndpoint_nsg"
}

resource "oci_core_network_security_group_security_rule" "oke_k8sApiEndpoint_nsg_ingressfromanywhere" {
    network_security_group_id = oci_core_network_security_group.oke_k8sApiEndpoint_nsg.id
    direction = "INGRESS"
    protocol = "6"
    description = "allows TCP connections on port 6443 from everywhere"
    source = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
        destination_port_range {
            max = 6443
            min = 6443
        }
    }
}

resource "oci_core_network_security_group" "oke_node_nsg" {
    compartment_id = "${var.compartment_ocid}"
    vcn_id = "${oci_core_vcn.oke_vcn.id}"
	display_name = "oke_node_nsg"
}

resource "oci_core_network_security_group" "oke_lb_nsg" {
    compartment_id = "${var.compartment_ocid}"
    vcn_id = "${oci_core_vcn.oke_vcn.id}"
	display_name = "oke_lb_nsg"
}

resource "oci_core_network_security_group" "oke_pod_nsg" {
    compartment_id = "${var.compartment_ocid}"
    vcn_id = "${oci_core_vcn.oke_vcn.id}"
	display_name = "oke_pod_nsg"
}

output "compartment" {
	value = var.compartment_ocid
}
output "vcn" {
	value = oci_core_vcn.oke_vcn.id
}
output "apiendpointsubnet" {
	value = oci_core_subnet.oke_k8sApiEndpoint_public_subnet.id
}
output "apiendpointnsg" {
	value = oci_core_network_security_group.oke_k8sApiEndpoint_nsg.id
}
output "virtualnodesubnet" {
	value = oci_core_subnet.oke_node_private_subnet.id
}
output "virtualnodensg" {
	value = oci_core_network_security_group.oke_node_nsg.id
}
output "podsubnet" {
	value = oci_core_subnet.oke_pod_private_subnet.id
}
output "podnsg" {
	value = oci_core_network_security_group.oke_pod_nsg.id
}
output "svclbsubnet" {
	value = oci_core_subnet.oke_svclb_public_subnet.id
}