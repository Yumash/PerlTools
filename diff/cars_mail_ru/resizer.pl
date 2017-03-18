#!/usr/bin/perl -w
use strict;
use Image::Resize;
open FF,"<images.list";
my @files = <FF>;
close FF;
foreach(@files){
    next if $_ !~ /\.jpg/;
    my $filename = $_;
    $filename =~ s|^\./|/home/common/diff/cars_mail_ru/pics/|;
    $filename =~ s/[\n\s]*$//;
    my $thumb = $filename;
    next if -e $thumb;
    $thumb =~ s/\.jpg/t.\.jpg/;
    eval {
        my $image = Image::Resize->new($filename);
        my $gd = $image->resize(200, 200);
        open(FH, ">".$thumb);
        print FH $gd->jpeg();
        close(FH);
    };
}

