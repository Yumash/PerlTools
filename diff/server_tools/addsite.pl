#!/usr/bin/perl -w
use strict;
use Term::ANSIColor;
my $colors = {
                'ok'        =>  q[green],
                'error'     =>  q[red],
                'notice'    =>  q[yellow]
            };
my $conf_dir = q[/etc/apache2/sites-available/];
my $sites_dir = q[/home/sites/];
sub m_notice {
    m_send('notice', @_);
}

sub m_ok {
    m_send('ok', @_);
}

sub m_error {
    m_send('error', @_);
}

sub m_send {
    my ($type, $message) = @_;
    if($message){
        my $date = getDate();
        print $date->{hour}.q[:].$date->{min}.q[:].$date->{sec};
        print color $colors->{$type};
        print q[ \[].uc($type)."] ";
        print color 'reset';
        print $message."\n";
    }
}

sub getDate {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my %time;
    $time{day}  = $mday;
    $time{mon}  = $mon+1;
    $time{year} = $year+1900;
    $time{hour} = $hour;
    $time{min}  = $min;
    $time{sec}  = $sec;
    return \%time;
}





my $conf_string = q[
    <VirtualHost *:80>
        ServerName %replace%
        ServerAlias www.%replace%
        DocumentRoot %sitedir%%replace%
        DirectoryIndex index.php index.html
        <Directory />
                Options FollowSymLinks
                AllowOverride All
        </Directory>
        ErrorLog /var/log/apache2/%replace%.error.log
        LogLevel warn
        CustomLog /var/log/apache2/%replace%.access.log combined
</VirtualHost>
];
if(!-w $conf_dir){
    m_error(qq[$conf_dir is not writable]);
    exit;
}
my $sitename = q[];
if(!$ARGV[0]){
    print qq[Enter new site: ];
    $sitename = <STDIN>;
    chop($sitename);
}
else{
    $sitename = $ARGV[0]; 
}
$sitename =~ s/^www\.//;
print qq[Adding $sitename\n];
print qq[Home Dir ($sites_dir): ];
my $tmp_site_dir = <STDIN>;
chop $tmp_site_dir;
$sites_dir = $tmp_site_dir if $tmp_site_dir;
$sites_dir = $sites_dir.q[/] if $sites_dir !~ /\/$/;
if(!-w $sites_dir){
    m_error(qq[$sites_dir is not writable]);
    exit;
}
if(-e $conf_dir.$sitename){
    m_error(qq[Config already exists]);
    exit;
}
$conf_string =~ s/%replace%/$sitename/g;
$conf_string =~ s/%sitedir%/$sites_dir/;

mkdir($sites_dir.$sitename) if !-e $sites_dir.$sitename;
open FF,">".$conf_dir.$sitename;
print FF $conf_string;
close FF;
m_ok(
     qq[Ready. Now please do the following:\n
    a2ensite $sitename\n
    /etc/init.d/apache2 reload
]);