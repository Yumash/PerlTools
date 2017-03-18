#!/usr/bin/perl -w
use strict;


if(!$ARGV[0] || $ARGV[0] !~ /^(master|slave|both)$/){
    print qq[Usage:\n\t"addbind master [site] [ip] [ns1] [ns2] [admin_email]" adds entry to master bind-server\n];
    print qq[\t"addbind slave [site] [ip] [ns1] [ns2] [admin_email]" adds entry to slave bind-server\n];
    print qq[\t"addbind both [site] [ip] [ns1] [ns2] [admin_email]" adds entry to slave bind-server\n];
    exit;
}

my $ip                  =   qq[85.10.200.108];
my $site                =   $ARGV[1] ? $ARGV[1] : undef;
my $master_dir          =   q[/etc/bind/sites/];
my $slave_dir           =   q[/var/cache/bind/];
my $master_config_file  =   q[/etc/bind/named.conf.local];
my $slave_config_file   =   q[/etc/bind/named.conf.slave];
my $ns1                 =   $ARGV[3] ? $ARGV[3] : q[ns.evilman.ru];
my $ns2                 =   $ARGV[4] ? $ARGV[4] : q[ns1.evilman.ru];
my $admin_email         =   $ARGV[5] ? $ARGV[5] : q[skazo4nik@gmail.com];
my $master_zone_template    =   q[/etc/bind/sites/common.zone];

if($ARGV[2] && $ARGV[2] =~ /^(\d+\.){3}\d+$/){
    $ip = $ARGV[2];
}
my $slave_template = q[
zone "%site%" {
    type slave;
    file "/var/cache/bind/%site%";
    masters {
        %ip%;
    };
};
];

my $master_template = q[zone "%site%" {
    type master;
    file "%master_dir%";
};

];

my $master_config_template = q[$ORIGIN %site%.
$TTL 86400 ; 1 day
@ IN SOA %ns1%. %admin_email%. (
    %serial%; serial
    10800 ; refresh (3 hours)
    3600 ; retry (15 minutes)
    3600000 ; expire (1 week)
    86400 ; minimum (1 day)
)
@ IN NS %ns1%.
@ IN NS %ns2%.
@ IN A %ip%

* IN A %ip%

];
print "\n\n";
if($ARGV[0] eq q[master] || $ARGV[0] eq q[both]){
    while(!-e $master_config_file || !-w $master_config_file){
        print qq|\t[-]\tBIND config file [$master_config_file] not exists or unwritable.|;
        print qq|\t   \tPlease, enter new config file path: |;
        $master_config_file = <STDIN>;
        chop $master_config_file;
    }
    
    print qq|\t[+]\tUsing config file $master_config_file\n|;
    
    while(!-e $master_dir || !-w $master_dir){
        print qq|\t[-]\tSites config directory [$master_dir] not exists on unwritable.\n|;
        print qq|\t   \tPlease, enter new sites config directory: |;
        $master_dir = <STDIN>;
        chop $master_dir;
        $master_dir = $master_dir.q[/] unless $master_dir =~ /\/$/;
    }
    
    print qq|\t[+]\tUsing config sites dir $master_dir\n|;
    
    while(!$admin_email){
        print qq|\t[-]\tPlease, enter email: |;
        $admin_email = <STDIN>;
        chop $admin_email;
    }
    print qq|\t[+]\tAdmin email: $admin_email\n|;
    $admin_email =~ s/@/./;
    while(!$ns1){
        print qq|\t[-]\tPlease, enter NS1: |;
        $ns1 = <STDIN>;
        chop $ns1;
    }
    print qq|\t[+]\tNS1: $ns1\n|;
    
    while(!$ns2){
        print qq|\t[-]\tPlease, enter NS2: |;
        $ns2 = <STDIN>;
        chop $ns2;
    }
    print qq|\t[+]\tNS2: $ns2\n|;
    
    while(!$ip){
        print qq|\t[-]\tPlease, master IP: |;
        $ip = <STDIN>;
        chop $ip;
    }    
    print qq|\t[+]\tA IP: $ip\n|;

    if($site){
        if(-e $master_dir.$site){
            print qq|\t[-]\t$master_dir$site already exists!\n\n|;
            $site = undef;
        }
    }
    while(!$site){
        print qq|\t[-]\tPlease, enter site: |;
        $site = <STDIN>;
        chop($site);
    }
    
    $site =~ s/^http:\/\///i;
    $site =~ s/www\.//i;
    $site = lc $site;
    
    if(`grep $site $master_config_file`){
        print qq[\t[-]\tZone $site exists in $master_config_file\n];
        exit;
    }
    print qq|\t[+]\tReady to write config for $site\n|;
    
    my $serial = getSerial();
    
    #$master_config_template =~ s/%ip%/$ip/g;
    #$master_config_template =~ s/%site%/$site/g;
    #$master_config_template =~ s/%ns1%/$ns1/g;
    #$master_config_template =~ s/%ns2%/$ns2/g;
    #$master_config_template =~ s/%admin_email%/$admin_email/g;
    #$master_config_template =~ s/%serial%/$serial/;
    
    #print $master_config_template."\n";
    
    $master_template =~ s/%site%/$site/g;
    #$master_template =~ s/%master_dir%/$master_dir/g;
    
    $master_template =~ s/%master_dir%/$master_zone_template/g;
    
    #print $master_template."\n";
    
    print qq|\t[*]\tTrying to backup $master_config_file...\n|;
    open FF,"<$master_config_file" or die qq|\t[-]\tCannot open $master_config_file for reading\n|;
    my @backup_file = <FF>;
    close FF;
    open FF,">$master_config_file.bak" or die qq |\t[-]\tCannot open $master_config_file.bak for writing\n|;
    print FF join("",@backup_file);
    close FF;
    print qq|\t[+]\t$master_config_file backuped into $master_config_file.bak\n|;
    
    open FF, ">>$master_config_file" or die qq|\t[-]\tCannot open $master_config_file for writing\n|;
    print FF $master_template;
    close FF;
    
    print qq|\t[+]\t$master_config_file appended successfully\n|;
    
    #open FF,">$master_dir$site" or die qq|\t[-]\tCannot open $master_dir$site for writing\n|;
    #print FF $master_config_template;
    #close FF;
    #
    #print qq|\t[+]\t$master_dir$site created successfully\n|;
    
    print qq|\n\n\t[*]\tPlease, do not forget to add entry to slave server and to restart BIND\n|;
    print qq|\t   \t/etc/init.d/bind9 reload\n\n|;
    print qq|\t   \tOR\n|;
    print qq|\t   \t/etc/init.d/bind9 restart\n\n|;
}

if($ARGV[0] eq q[slave] || $ARGV[0] eq q[both]){
    while(!-e $slave_config_file || !-w $slave_config_file){
        print qq|\t[-]\tBIND config file [$slave_config_file] not exists or unwritable.|;
        print qq|\t   \tPlease, enter new config file path: |;
        $slave_config_file = <STDIN>;
        chop $slave_config_file;
    }
    print qq|\t[+]\tSlave zones file $slave_config_file\n|;
    
    if($site){
        if(-e $slave_dir.$site){
            print qq|\t[-]\t$slave_dir$site already exists!\n\n|;
            $site = undef;
        }
    }
    while(!$site){
        print qq|\t[-]\tPlease, enter site: |;
        $site = <STDIN>;
        chop($site);
    }
    
    $site =~ s/^http:\/\///i;
    $site =~ s/www\.//i;
    $site = lc $site;    
    print qq|\t[+]\tSite $site\n|;

    while(!$ip){
        print qq|\t[-]\tPlease, master IP: |;
        $ip = <STDIN>;
        chop $ip;
    }    
    print qq|\t[+]\tMaster IP: $ip\n|;
    
    $slave_template =~ s/%ip%/$ip/g;
    $slave_template =~ s/%site%/$site/g;
    
    print qq|\t[*]\tTrying to backup $slave_config_file...\n|;
    open FF,"<$slave_config_file" or die qq|\t[-]\tCannot open $slave_config_file for reading\n|;
    my @backup_file = <FF>;
    close FF;
    open FF,">$master_config_file.bak" or die qq |\t[-]\tCannot open $slave_config_file.bak for writing\n|;
    print FF join("",@backup_file);
    close FF;
    print qq|\t[+]\t$slave_config_file backuped into $slave_config_file.bak\n|;
    
    open FF, ">>$slave_config_file" or die qq|\t[-]\tCannot open $slave_config_file for writing\n|;
    print FF $slave_template;
    close FF;
    
    print qq|\t[+]\t$slave_config_file appended successfully\n|;    
}


sub getSerial {
    my ($sec,$min,$hour,$mday,$mon,$year)=localtime(time);
    return ($year+1900).($mon+1).$mday.q[01];
}
