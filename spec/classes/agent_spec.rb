require 'spec_helper'

describe 'zabbix::agent' do
  let :node do
    'agent.example.com'
  end
  let :params do
    {
      server: '192.168.1.1',
      serveractive: '192.168.1.1',
      agent_configfile_path: '/etc/zabbix/zabbix_agentd.conf'
    }
  end

  on_supported_os.each do |os, facts|
    context "on #{os} " do
      systemd_fact = case facts[:osfamily]
                     when 'Archlinux', 'Fedora', 'Gentoo'
                       { systemd: true }
                     else
                       { systemd: false }
                     end
      config_path = case facts[:operatingsystem]
                    when 'Fedora'
                      '/etc/zabbix_agentd.conf'
                    else
                      '/etc/zabbix/zabbix_agentd.conf'
                    end
      let :facts do
        facts.merge(systemd_fact)
      end

      if facts[:osfamily] == 'Gentoo'
        package_name = 'zabbix'
        service_name = 'zabbix-agentd'
      else
        package_name = 'zabbix-agent'
        service_name = 'zabbix-agent'
      end
      # package = facts[:osfamily] == 'Gentoo' ? 'zabbix' : 'zabbix-agent'
      # service = facts[:osfamily] == 'Gentoo' ? 'zabbix-agentd' : 'zabbix-agent'

      context 'with all defaults' do
        # Make sure package will be installed, service running and ensure of directory.
        it do
          is_expected.to contain_package(package_name).with(
            ensure:   'present',
            require:  'Class[Zabbix::Repo]',
            tag:      'zabbix'
          )
        end

        it do
          is_expected.to contain_service(service_name).with(
            ensure:     'running',
            enable:     true,
            hasstatus:  true,
            hasrestart: true,
            require:    "Package[#{package_name}]"
          )
        end

        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.d').with_ensure('directory') }
        it { is_expected.to contain_zabbix__startup(service_name).that_requires("Package[#{package_name}]") }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('zabbix::params') }
      end

      context 'when declaring manage_repo is true' do
        let :params do
          {
            manage_repo: true
          }
        end

        case facts[:osfamily]
        when 'Archlinux'
          it { is_expected.not_to compile.with_all_deps }
        when 'Debian'
          # rubocop:disable RSpec/RepeatedExample
          it { is_expected.to contain_class('zabbix::repo').with_zabbix_version('3.4') }
          it { is_expected.to contain_package('zabbix-agent').with_require('Class[Zabbix::Repo]') }
          it { is_expected.to contain_apt__source('zabbix') }
        when 'RedHat'
          it { is_expected.to contain_class('zabbix::repo').with_zabbix_version('3.4') }
          it { is_expected.to contain_package('zabbix-agent').with_require('Class[Zabbix::Repo]') }
          it { is_expected.to contain_yumrepo('zabbix-nonsupported') }
          it { is_expected.to contain_yumrepo('zabbix') }
          # rubocop:enable RSpec/RepeatedExample
        end
      end

      context 'when declaring manage_resources is true' do
        let :params do
          {
            manage_resources: true
          }
        end

        it { is_expected.to contain_class('zabbix::resources::agent') }
      end

      context 'configuration file with hostnameitem' do
        let :params do
          {
            hostnameitem: 'system.hostname'
          }
        end

        it { is_expected.to contain_file(config_path).with_content %r{^HostnameItem=system.hostname$} }
      end

      context 'ignores hostnameitem if hostname is set' do
        let :params do
          {
            hostname: 'test',
            hostnameitem: 'system.hostname'
          }
        end

        it { is_expected.to contain_file(config_path).without_content %r{^HostnameItem=system.hostname$} }
        it { is_expected.to contain_file(config_path).with_content %r{^Hostname=test$} }
      end

      context 'when declaring manage_firewall is true' do
        let :params do
          {
            manage_firewall: true
          }
        end

        it { is_expected.to contain_firewall('150 zabbix-agent') }
      end

      context 'when declaring manage_firewall is false' do
        let :params do
          {
            manage_firewall: false
          }
        end

        it { is_expected.not_to contain_firewall('150 zabbix-agent') }
      end

      context 'it creates a startup script' do
        case facts[:osfamily]
        when 'Archlinux', 'Fedora', 'Gentoo'
          it { is_expected.to contain_file("/etc/init.d/#{service_name}").with_ensure('absent') }
          it { is_expected.to contain_file("/etc/systemd/system/#{service_name}.service").with_ensure('file') }
        else
          it { is_expected.to contain_file("/etc/init.d/#{service_name}").with_ensure('file') }
          it { is_expected.not_to contain_file("/etc/systemd/system/#{service_name}.service") }
        end
      end

      context 'when declaring manage_startup_script is false' do
        let :params do
          {
            manage_startup_script: false
          }
        end

        it { is_expected.not_to contain_zabbix__startup(service_name) }
      end

      context 'when declaring zabbix_alias' do
        let :params do
          {
            zabbix_alias: %w[testname]
          }
        end

        it { is_expected.to contain_file(config_path).with_content %r{^Alias=testname$} }
      end

      context 'when declaring zabbix_alias as array' do
        let :params do
          {
            zabbix_alias: %w[name1 name2]
          }
        end

        it { is_expected.to contain_file(config_path).with_content %r{^Alias=name1$} }
        it { is_expected.to contain_file(config_path).with_content %r{^Alias=name2$} }
      end

      context 'configuration file with full options' do
        let :params do
          {
            allowroot: '0',
            agent_configfile_path: '/etc/zabbix/zabbix_agentd.conf',
            buffersend: '5',
            buffersize: '100',
            debuglevel: '4',
            enableremotecommands: '1',
            hostname: '10050',
            include_dir: '/etc/zabbix/zabbix_agentd.d',
            listenport: '10050',
            listenip: '127.0.0.1',
            loadmodulepath: '${libdir}/modules',
            logfilesize: '4',
            logfile: '/var/log/zabbix/zabbix_agentd.log',
            logremotecommands: '0',
            pidfile: '/var/run/zabbix/zabbix_agentd.pid',
            refreshactivechecks: '120',
            server: '192.168.1.1',
            serveractive: '192.168.1.1',
            startagents: '3',
            timeout: '30',
            unsafeuserparameters: '0',
            tlsconnect: 'cert',
            tlsaccept: 'cert',
            tlscafile: '/etc/zabbix/keys/file.ca',
            tlscrlfile: '/etc/zabbix/keys/file.crl',
            tlsservercertissuer: 'Zabbix.Com',
            tlsservercertsubject: 'MySubJect',
            tlscertfile: '/etc/zabbix/keys/tls.crt',
            tlskeyfile: '/etc/zabbix/keys/tls.key',
            tlspskidentity: '/etc/zabbix/keys/tlspskidentity.id',
            tlspskfile: '/etc/zabbix/keys/tlspskfile.key'
          }
        end

        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^AllowRoot=0$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^BufferSend=5$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^BufferSize=100$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^DebugLevel=4$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^EnableRemoteCommands=1$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^Hostname=10050$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^Include=/etc/zabbix/zabbix_agentd.d$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^ListenPort=10050$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^ListenIP=127.0.0.1$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^LoadModulePath=\$\{libdir\}/modules$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^LogFileSize=4$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^LogFile=/var/log/zabbix/zabbix_agentd.log$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^LogRemoteCommands=0$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^PidFile=/var/run/zabbix/zabbix_agentd.pid$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^RefreshActiveChecks=120$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^Server=192.168.1.1$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^ServerActive=192.168.1.1$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^StartAgents=3$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^Timeout=30$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^UnsafeUserParameters=0$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^TLSConnect=cert$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^TLSAccept=cert$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^TLSCAFile=/etc/zabbix/keys/file.ca$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^TLSCRLFile=/etc/zabbix/keys/file.crl$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^TLSServerCertIssuer=Zabbix.Com$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^TLSServerCertSubject=MySubJect$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^TLSCertFile=/etc/zabbix/keys/tls.crt$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^TLSKeyFile=/etc/zabbix/keys/tls.key$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^TLSPSKIdentity=/etc/zabbix/keys/tlspskidentity.id$} }
        it { is_expected.to contain_file('/etc/zabbix/zabbix_agentd.conf').with_content %r{^TLSPSKFile=/etc/zabbix/keys/tlspskfile.key$} }
      end

      context 'without ListenIP' do
        let :params do
          {
            listenip: '*'
          }
        end

        it { is_expected.to contain_file(config_path).without_content %r{^ListenIP=} }
      end

      context 'when declaring service_ensure is stopped and service_enable false' do
        let :params do
          {
            service_ensure: 'stopped',
            service_enable: false
          }
        end

        it do
          is_expected.to contain_service(service_name).with(
            ensure:     'stopped',
            enable:     false,
            require:    "Package[#{package_name}]"
          )
        end
      end
    end
  end
end
