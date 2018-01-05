Facter.add('rhsm_subscribed') do
  confine :osfamily => 'RedHat'
  setcode do
    if Facter::Util::Resolution.exec('subscription-manager status && echo true') == 'true'
      Puppet.debug "rhsm_repos.rb RHSM: Machine subscribed"
      true
    else
      Puppet.debug "rhsm_repos.rb RHSM: Machine not subscribed"
      false
    end
  end
end

Facter.add('rhsm_repos') do
  confine :osfamily => 'RedHat'
  setcode do
    repos = Array.[]
    if Facter::Util::Resolution.exec('subscription-manager status && echo true') == 'true'
      repo_list = Facter::Core::Execution.exec("subscription-manager repos --list-enabled | awk '/Repo ID:/ {print $3}'")
      repo_list.each_line do |line|
        repos.push(line.strip)
      end
      repos
    else
      repos
    end
  end
end
