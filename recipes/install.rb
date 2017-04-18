# install the mongodb_org_repo if necessary
include_recipe 'sc-mongodb::mongodb_org_repo' if %w(10gen mongodb-org).include?(node['mongodb']['install_method'])

#build_essential 'build-tools'

# prevent-install defaults, but don't overwrite
file node['mongodb']['sysconfig_file'] do
  content 'ENABLE_MONGODB=no'
  group node['mongodb']['root_group']
  owner 'root'
  mode 0644
  action :create_if_missing
end

# just-in-case config file drop
template node['mongodb']['dbconfig_file'] do
  cookbook node['mongodb']['template_cookbook']
  source node['mongodb']['dbconfig_file_template']
  group node['mongodb']['root_group']
  owner 'root'
  mode 0644
  variables(
    config: node['mongodb']['config']
  )
  helpers MongoDBConfigHelpers
  action :create_if_missing
end

# and we install our own init file
if node['mongodb']['apt_repo'] == 'ubuntu-upstart'
  init_file = File.join(node['mongodb']['init_dir'], "#{node['mongodb']['default_init_name']}.conf")
  mode = '0644'
else
  init_file = File.join(node['mongodb']['init_dir'], node['mongodb']['default_init_name'])
  mode = '0755'
end

# Reload systemctl for RHEL 7+ after modifying the init file.
execute 'mongodb-systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

template init_file do
  cookbook node['mongodb']['template_cookbook']
  source node['mongodb']['init_script_template']
  group node['mongodb']['root_group']
  owner 'root'
  mode mode
  variables(
    provides: 'mongod',
    dbconfig_file: node['mongodb']['dbconfig_file'],
    sysconfig_file: node['mongodb']['sysconfig_file'],
    ulimit: node['mongodb']['ulimit'],
    bind_ip: node['mongodb']['config']['bind_ip'],
    port: node['mongodb']['config']['port'],
    user: node['mongodb']['user']
  )
  action :create_if_missing

  if platform_family?('rhel') && node['platform'] != 'amazon' && node['platform_version'].to_i >= 7
    notifies :run, 'execute[mongodb-systemctl-daemon-reload]', :immediately
  end
end

# install
package node['mongodb']['package_name'] do
  options node['mongodb']['packager_options']
  action :install
  version node['mongodb']['package_version']
  not_if { node['mongodb']['install_method'] == 'none' }
end

# Create keyFile if specified
if node['mongodb']['key_file_content']
  file node['mongodb']['config']['keyFile'] do
    owner node['mongodb']['user']
    group node['mongodb']['group']
    mode  '0600'
    backup false
    content node['mongodb']['key_file_content']
  end
end
