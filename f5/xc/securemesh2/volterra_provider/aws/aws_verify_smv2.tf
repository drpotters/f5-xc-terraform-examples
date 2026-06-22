resource "volterra_securemesh_site_v2" "smv2-aws-tf-one" {
  name      = "smv2-aws-tf-one"
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
  // One of the arguments from this list "aws aws baremetal gcp kvm nutanix oci openstack rseries vmware" must be set

  aws {
    // One of the arguments from this list "not_managed" can be set

    not_managed {

      node_list {
        hostname = "aws-tf-ctrl-0"

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "ens5"
            mac    = "7c:1e:52:50:dc:02"
          }

          // is_primary = true
          name = "ens5"
          network_option {
            site_local_network = true
          }
        }

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "ens6"
            mac    = "60:45:bd:50:dc:08"
          }

          // is_primary = true
          name = "ens6"
          network_option {
            site_local_inside_network = true
          }
        }
        type = "Control"
      }

      node_list {
        hostname = "aws-tf-ctrl-1"

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "ens5"
            mac    = "7c:1e:52:50:dc:12"
          }

          // is_primary = true
          name = "ens5"
          network_option {
            site_local_network = true
          }
        }

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "ens6"
            mac    = "60:45:bd:50:dc:18"
          }

          // is_primary = true
          name = "ens6"
          network_option {
            site_local_inside_network = true
          }
        }
        type = "Control"
      }

      node_list {
        hostname = "aws-tf-ctrl-2"

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "ens5"
            mac    = "7c:1e:52:50:dc:22"
          }

          // is_primary = true
          name = "ens5"
          network_option {
            site_local_network = true
          }
        }

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "ens6"
            mac    = "60:45:bd:50:dc:28"
          }

          // is_primary = true
          name = "ens6"
          network_option {
            site_local_inside_network = true
          }
        }
        type = "Control"
      }
      node_list {
        hostname = "aws-tf-wrkr-1"

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "ens5"
            mac    = "7c:1e:52:50:dc:32"
          }

          // is_primary = true
          name = "ens5"
          network_option {
            site_local_network = true
          }
        }

        interface_list {
          dhcp_client = true
          ethernet_interface {
            device = "ens6"
            mac    = "60:45:bd:50:dc:38"
          }

          // is_primary = true
          name = "ens6"
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
