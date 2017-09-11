# rhsm
#
# Subscribe the node to RHSM
#
# Copyright 2014 Ger Apeldoorn, unless otherwise noted.
#
# @summary Subscribe the node to RHSM
#
# @param rh_user [String] User for the Customer Portal.
#   You need to specify either (rh_user and rh_password) or (org and activationkey)
# @param rh_password [String] Password for the rh_user account
# @param org [String] Organization to use
# @param activationkey [String] Activationkey to use
# @param servername [String] Servername, default provided
#   Used directly in rhsm.conf template
# @param pool [String] Attach system to a specific pool instead of auto attach to compatible subscriptions
# @param proxy_hostname [String] Proxy hostname
# @param proxy_port [String] Proxy port
# @param proxy_user [String] Proxy user
# @param proxy_password [String] Proxy password
# @param baseurl [String] Base URL for rhsm, default provided
# @param package_ensure [String] Whether to install subscription-manager
# @param repo_extras [Boolean] Enable extras repository
# @param repo_optional [Boolean] Enable optional repository
#
# @example
#   include rhsm
#
# @example
#   # Hierafile:
#   ---
#   rhsm::rh_user: myuser
#   rhsm::rh_password: mypassword
#
# @author Ger Apeldoorn <info@gerapeldoorn.nl>
#
class rhsm (
  $rh_user        = undef,
  $rh_password    = undef,
  $org            = undef,
  $activationkey  = undef,
  $servername     = 'subscription.rhn.redhat.com',
  $pool           = undef,
  $proxy_hostname = undef,
  $proxy_port     = undef,
  $proxy_user     = undef,
  $proxy_password = undef,
  $baseurl        = 'https://cdn.redhat.com',
  $package_ensure = 'latest',
  $repo_extras    = false,
  $repo_optional  = false
) {

  if ($rh_user == undef and $rh_password == undef) and ($org == undef and $activationkey == undef) {
    fail("${module_name}: Must provide rh_user and rh_password or org and activationkey")
  }

  if $rh_user {
    $_user = " --username='${rh_user}'"
  } else {
    $_user = ''
  }

  if $rh_password {
    $_password = " --password='${rh_password}'"
  } else {
    $_password = ''
  }

  if $org {
    $_org = " --org='${org}'"
  } else {
    $_org = ''
  }

  if $activationkey {
    $_activationkey = " --activationkey='${activationkey}'"
  } else {
    $_activationkey = ''
  }

  if $proxy_hostname {
    if $proxy_user and $proxy_password {
      $proxycli = " --proxy=http://${proxy_hostname}:${proxy_port} --proxyuser=${proxy_user} --proxypass=${proxy_password}"
    } else {
      $proxycli = " --proxy=http://${proxy_hostname}:${proxy_port}"
    }
  } else {
    $proxycli = ''
  }

  if $pool == undef {
    $command = "subscription-manager attach --auto${proxycli}"
  } else {
    $command = "subscription-manager attach --pool=${pool}${proxycli}"
  }

  package { 'subscription-manager':
    ensure => $package_ensure,
  }

  exec {'sm yum clean all':
    command     => '/usr/bin/yum clean all',
    refreshonly => true,
    subscribe   => Package['subscription-manager'],
  }

  file { '/etc/rhsm/rhsm.conf':
    ensure  => file,
    content => template('rhsm/rhsm.conf.erb'),
  }

  exec { 'RHNSM-register':
    command => "subscription-manager register --name='${::fqdn}'${_user}${_password}${_org}${_activationkey}${proxycli}",
    onlyif  => 'subscription-manager identity 2>&1 | grep "not yet registered"',
    path    => '/bin:/usr/bin:/usr/sbin',
    require => Package['subscription-manager'],
  }

  exec { 'RHNSM-subscribe':
    command => $command,
    onlyif  => 'subscription-manager list 2>&1 | grep "Expired\|Not Subscribed\|Unknown"',
    path    => '/bin:/usr/bin:/usr/sbin',
    require => Exec['RHNSM-register'],
  }

  if $repo_extras {
    ::rhsm::repo { "rhel-${::operatingsystemmajrelease}-server-extras-rpms":
      require => Exec['RHNSM-register'],
    }
  }

  if $repo_optional {
    ::rhsm::repo { "rhel-${::operatingsystemmajrelease}-server-optional-rpms":
      require => Exec['RHNSM-register'],
    }
  }

}
