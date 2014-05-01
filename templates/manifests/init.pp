class svnserver (
    $path                 = $title,
    $user                 = 'subversion',
    $anonymous_access     = 'none', # options: read, write, none
    $authenticated_access = 'write', # options: read, write, none
    $password_db          = 'passwd',
    $users                = {
        'defaultuser' => 'defaultusersecret',
    }
    ,
    $setup_apache		  = false,
    $install_apache       = false,
    $install_apache_utils = false,
    $http_passwd_path     = undef,) {

    if ($http_passwd_path == nil) {
		$httpPasswordPath = "$path/conf/httpd_passwd"
	} else {
		$httpPasswordPath = $http_passwd_path
	}

    apt::source { 'svn':
        location    => 'http://ppa.launchpad.net/svn/ppa/ubuntu',
        release     => 'raring',
        repos       => 'main',
        pin         => 99,
        include_src => false,
        key_server  => 'keyserver.ubuntu.com',
        key         => 'A2F4C039'
    } ->
    package { 'subversion': ensure => present, } ->
    user { $user:
        ensure => present,
        system => true,
    } ->
    file { $path:
        ensure => directory,
        owner  => $user,
        group  => $user,
    } ->
    exec { "chown -R $user:$user $path ": logoutput => true } ->
    exec { "create repo at $path":
        command => "svnadmin create $path",
        creates => "$path/format",
        user    => $user,
    } ->
    file { "$path/conf/svnserve.conf": content => template("svnserver/svnserve.conf.erb"), } ->
    file { "$path/conf/$password_db": content => template("svnserver/passwd.erb"), } ->
    file { "/etc/init.d/svnserve":
        content => template("svnserver/svnserve.erb"),
        owner   => 'root',
        group   => 'root',
        mode    => 'a+x',
    } ->
    service { "svnserve":
        ensure     => running,
        hasrestart => true,
        hasstatus  => false,
        enable     => true,
    }

    if ($setup_apache) {
        $createPasswdScriptPath = '/var/tmp/create_htpasswd.sh'

        apt::ppa { 'ppa:ondrej/apache2': }

        if ($install_apache) {
            class { 'apache':
                package_ensure      => latest,
                default_mods        => false,
                default_confd_files => false,
                before              => Package["libapache2-svn"],
                require             => [Apt::PPA['ppa:ondrej/apache2'],
                                        Exec["create repo at $path"],
                                       ],
            }
        }

        if ($install_apache_utils) {
            package { "apache2-utils":
                ensure  => latest,
                require => Apt::PPA['ppa:ondrej/apache2'],
                before  => File[$createPasswdScriptPath],
            }
        }

        package { "libapache2-svn":
            ensure  => latest,
            require => Apt::PPA['ppa:ondrej/apache2'],
        } ->
        class { 'apache::mod::auth_basic': } ->
        class { 'apache::mod::dav_svn': } ->
        apache::mod {['authz_user', 'authz_svn', 'authn_core', 'authn_file']:} ->

       # file { '/etc/apache2/mods-available/dav_svn.conf': content => template('svnserver/httpd/dav_svn.conf.erb'), } ->
        file { $createPasswdScriptPath:
            content => template('svnserver/httpd/create_htpasswd.sh.erb'),
            mode    => 'a+x',
        } ->
        exec { "$createPasswdScriptPath ": logoutput => false, } ->
        exec { "rm $createPasswdScriptPath": logoutput => false } ->

        exec { "chown -R www-data:$user $path ": logoutput => true } ->

        exec { "chmod -R 774 $path ": logoutput => true }
    }
}
