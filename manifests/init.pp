class svnserver (
	$path = '/var/tmp/repo',
	$user = 'subversion',
	$anonymous_access = 'none', # options: read, write, none
	$authenticated_access = 'write', # options: read, write, none
	$password_db = 'passwd',
	$users = {
		'defaultuser' => 'defaultusersecret',
	},
) {
	package {'subversion': 
	  	ensure => present,
	} ->
	user {$user:
		ensure => present,
        system => true,
	} ->
	file {$path:
		ensure => directory,
		owner  => $user,
		group  => $user,
	} ->
	exec {"create repo at $path":
		command => "svnadmin create $path",
		creates => "$path/format",
		user 	=> $user,
	} -> 
	file {"$path/conf/svnserve.conf":
		content => template("svnserver/svnserve.conf.erb"),
	} ->
	file {"$path/conf/$password_db":
		content => template("svnserver/passwd.erb"),
	}
	file {"/etc/init.d/svnserve":
		content => template("svnserver/svnserve.erb"),
		owner   => 'root',
		group   => 'root',
		mode    => 'a+x',
	} ->
	service {"svnserve":
		ensure     => running,
		hasrestart => true,
		hasstatus  => false,
		enable     => true,
	}
}