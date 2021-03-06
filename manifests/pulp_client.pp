# profile::pulp_client - Software Repos for Pulp Clients
class profile::pulp_client (
  $server_protocol = 'https',
  $server_name = undef,
  $server_ip = undef,
  $extra_repos = [],
  $disable_warning = false,
  $ca_cert = 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem',
) {

  if ($::os[family] == 'RedHat') { # Only affect Red Hat family servers
    # Trust Pulp CA Cert
    include ::ca_cert
    ca_cert::ca {'PulpCA':
      ensure => 'trusted',
      source => $ca_cert
    }

    # Red Hat Family Common
    include pulp::consumer

    if $server_name {
      case $::operatingsystem {
        'CentOS': {
          include repos::centos
          #include repos::larkit
          include repos::pulp2
          include repos::epel
          include repos::puppetlabs_pc1
          include $extra_repos

          # Purge all non-managed repos!
          resources { 'yumrepo':
            purge => true,
          }
        }
        # Future support of RHEL or Amazon Linux
        default: {
          if (!str2bool($disable_warning)) {
            notify { "WARNING: ${module_name} doesnt support ${::operatingsystem}": }
          }
        }
      }
    }

    # Ordering
    #Yumrepo <| |> -> Ca_cert::Ca <| |> -> Package <| provider != 'rpm' |> # - causes cyclic dependency
    Yumrepo <| |> -> Package <| provider != 'rpm' |>
    #Ca_cert::Ca['PulpCA'] -> Package <| title != 'ca-certificates' |>

    ## Firewall
    if str2bool($::settings::storeconfigs) {
        # Pick up the rules that were left for us.
        Firewall <<| tag == 'fw_pulp_out' |>>
    }

    if ($server_ip) {
      firewall { "200 OUTPUT http/https (tcp) to ${server_name}":
        dport       => ['80', '443'],
        proto       => 'tcp',
        action      => 'accept',
        chain       => 'OUTPUT',
        destination => $server_ip,
      }
    }
  }
}
