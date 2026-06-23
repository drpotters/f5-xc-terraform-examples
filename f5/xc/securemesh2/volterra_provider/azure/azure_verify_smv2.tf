resource "volterra_securemesh_site_v2" "smv2-azure-tf-one" {
  name      = "smv2-azure-tf-one"
  namespace = "system"

  // One of the arguments from this list "block_all_services blocked_services" must be set

  block_all_services = true
  tunnel_type        = "SITE_TO_SITE_TUNNEL_IPSEC_OR_SSL"
  f5_proxy           = true

  enable_ha = true
  #disable_ha = true


  // One of the arguments from this list "log_receiver logs_streaming_disabled" must be set
  logs_streaming_disabled = true

  load_balancing {
    vip_vrrp_mode = "VIP_VRRP_INVALID"
  }
  // One of the arguments from this list "aws azure baremetal gcp kvm nutanix oci openstack rseries vmware" must be set

  azure {
    // One of the arguments from this list "not_managed" can be set

    not_managed {

      node_list {
        hostname = "azure-tf-ctrl-0"

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "eth0"
            mac    = "7c:1e:52:48:db:02"
          }

          // is_primary = true
          name = "eth0"
          network_option {
            site_local_network = true
          }
        }

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "eth1"
            mac    = "60:45:bd:d4:d8:08"
          }

          // is_primary = true
          name = "eth1"
          network_option {
            site_local_inside_network = true
          }
        }
        type = "Control"
      }

      node_list {
        hostname = "azure-tf-ctrl-1"

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "eth0"
            mac    = "7c:1e:52:48:db:12"
          }

          // is_primary = true
          name = "eth0"
          network_option {
            site_local_network = true
          }
        }

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "eth1"
            mac    = "60:45:bd:d4:d8:18"
          }

          // is_primary = true
          name = "eth1"
          network_option {
            site_local_inside_network = true
          }
        }
        type = "Control"
      }

      node_list {
        hostname = "azure-tf-ctrl-2"

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "eth0"
            mac    = "7c:1e:52:48:db:22"
          }

          // is_primary = true
          name = "eth0"
          network_option {
            site_local_network = true
          }
        }

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "eth1"
            mac    = "60:45:bd:d4:d8:28"
          }

          // is_primary = true
          name = "eth1"
          network_option {
            site_local_inside_network = true
          }
        }
        type = "Control"
      }
      node_list {
        hostname = "azure-tf-wrkr-1"

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "eth0"
            mac    = "7c:1e:52:48:db:32"
          }

          // is_primary = true
          name = "eth0"
          network_option {
            site_local_network = true
          }
        }

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "eth1"
            mac    = "60:45:bd:d4:d8:38"
          }

          // is_primary = true
          name = "eth1"
          network_option {
            site_local_inside_network = true
          }
        }
        type = "Worker"
      }



    }
  }


  software_settings {
    os {
      operating_system_version = "9.2025.39"
    }
    sw {
      volterra_software_version = "crt-20250701-0190"
    }
  }

}
