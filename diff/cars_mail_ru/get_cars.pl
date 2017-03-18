#!/usr/bin/perl -w
use strict;
use lib qw[../../lib];
use Parser::MailRu::Auto;
use Data::Dumper;
use Jum::DB;
use Jum::Logger;
use Jum::Web::Crawler;
use Text::Iconv;
use Digest::MD5 qw[md5_hex];
use Jum::Tools;

my $processName = q[MailRuCarsParser];
exit if Jum::Tools::isStarted($processName);
$0 = $processName;

my $converter = new Text::Iconv(q[windows-1251], q[utf8]);
my $parser = new Parser::MailRu::Auto();


my $dbh = Jum::DB::connect(q[auto_mail_ru]);
if(!$dbh){
    Jum::Logger::error(q[Failed connecting to DB]);
    exit;
}
my $pics_folder = q[/home/common/diff/cars_mail_ru/pics/];

my %queries_pool;
$queries_pool{get_task}     =   q[
                                    SELECT
                                        queue_id,
                                        queue_href
                                    FROM grab_queue
                                    WHERE queue_status = 'queued'
                                    /*ORDER BY RAND()*/
                                    ORDER BY queue_id DESC 
                                    LIMIT 1
                                    /*AND queue_id = 14068*/
                                ];
                        
$queries_pool{set_error}    =   q[UPDATE grab_queue SET queue_status = 'error' WHERE queue_id = ?];

$queries_pool{set_done}     =   q[UPDATE grab_queue SET queue_status = 'done' WHERE queue_id = ?];

$queries_pool{get_status}   =   q[SELECT status_id FROM car_status_list WHERE status_name_md5 = MD5(?)];
$queries_pool{set_status}   =   q[INSERT INTO car_status_list SET status_name = ?, status_name_md5 = MD5(?)];

$queries_pool{get_model}    =   q[SELECT model_id FROM model_list WHERE model_name_md5 = MD5(?)];
$queries_pool{set_model}    =   q[INSERT INTO model_list SET model_name = ?, model_name_md5 = MD5(?)];

$queries_pool{get_brand}    =   q[SELECT brand_id FROM brand_list WHERE brand_name_md5 = MD5(?)];
$queries_pool{set_brand}    =   q[INSERT INTO brand_list SET brand_name = ?, brand_name_md5 = MD5(?)];

$queries_pool{get_body}     =   q[SELECT body_id FROM car_body_list WHERE body_name_md5 = MD5(?)];
$queries_pool{set_body}     =   q[INSERT INTO car_body_list SET body_name = ?, body_name_md5 = MD5(?)];

$queries_pool{get_complect_parent}  =   q[
                                            SELECT complectation_id
                                            FROM complectation_list
                                            WHERE complectation_md5 = MD5(CONCAT(?,0))
                                        ];
                                        
$queries_pool{set_complect_parent}  =   q[
                                            INSERT INTO complectation_list
                                            SET
                                                complectation_name = ?,
                                                complectation_parent_id = 0,
                                                complectation_md5 = MD5(CONCAT(?,0))
                                        ];

$queries_pool{get_complect_entry}  =   q[
                                            SELECT complectation_id
                                            FROM complectation_list
                                            WHERE complectation_md5 = MD5(CONCAT(?,?))
                                        ];
                                        
$queries_pool{set_complect_entry}  =   q[
                                            INSERT INTO complectation_list
                                            SET
                                                complectation_name = ?,
                                                complectation_parent_id = ?,
                                                complectation_md5 = MD5(CONCAT(?,?))
                                        ];
                                        
$queries_pool{get_seller}           =   q[
                                            SELECT seller_id FROM sellers
                                            WHERE seller_md5 = MD5(CONCAT(?,?))
                                        ];
$queries_pool{set_seller}           =   q[
                                            INSERT INTO sellers
                                            SET
                                                seller_name = ?,
                                                is_salon = ?,
                                                seller_phones = ?,
                                                seller_website = ?,
                                                seller_address = ?,
                                                seller_city = ?,
                                                seller_email = ?,
                                                seller_md5 = MD5(CONCAT(?,?))
                                        ];

$queries_pool{get_car}              =   q[SELECT car_id FROM cars WHERE f_queue_id = ?];

$queries_pool{set_car}              =   q[
                                            INSERT INTO cars
                                            SET
                                                f_queue_id = ?,
                                                f_model_id = ?,
                                                f_brand_id = ?,
                                                f_body_id = ?,
                                                f_status_id = ?,
                                                f_seller_id = ?,
                                                car_year = ?,
                                                car_price = ?,
                                                car_distance = ?,
                                                car_description = ?
                                        ];
                                        
$queries_pool{set_complectation}    =   q[
                                            INSERT IGNORE
                                            INTO car_complectation
                                            SET
                                                f_car_id = ?,
                                                f_complectation_id = ?
                                        ];

$queries_pool{get_option_id}        =   q[SELECT option_id FROM options_list WHERE option_name_md5 = MD5(?)];
$queries_pool{set_option_id}        =   q[INSERT INTO options_list SET option_name = ?, option_name_md5 = MD5(?)];
$queries_pool{set_option}           =   q[INSERT IGNORE INTO car_options SET f_car_id = ?, f_option_id = ?, co_value = ?];

Jum::Logger::notice(q[Starting work...]);
while(1){
    
    my @task = $dbh->selectrow_array($queries_pool{get_task});
    last if $#task == -1;
    Jum::Logger::notice(qq[Got in work - $task[0]\t$task[1]]);
    parseCar(\@task);
    sleep(3);
}

sub parseCar {
    my $task = shift;
    my $content = Jum::Web::Crawler::getURL({href=>$task->[1]});
    if($content->{retcode} == 0 && $content->{http_code} == 200){
        $content->{content} = $converter->convert($content->{content});
        open FF,">./content";
        print FF $content->{content};
        close FF;
        Jum::Logger::notice(qq[Successfully got $task->[0]\t$task->[1]]);
        my $car_brand       =   $parser->getCarBrand(\$content->{content});
        my $car_model       =   $parser->getCarModel(\$content->{content});
        my $car_year        =   $parser->getCarYear(\$content->{content});
        my $car_price       =   $parser->getCarPrice(\$content->{content});
        my $car_distance    =   $parser->getCarDistance(\$content->{content});
        my $car_status      =   $parser->getCarStatus(\$content->{content});
        my $car_options     =   $parser->getCarOptions(\$content->{content});
        my $car_body        =   $parser->getCarBody(\$content->{content});
        my $car_description =   $parser->getCarDescription(\$content->{content});
        
        my $car_images      =   $parser->getCarImages(\$content->{content});
    
        my $car_complect    =   $parser->getCarComplect(\$content->{content});
        
        my $car_seller  =   $parser->getCarSeller(\$content->{content});
        
        Jum::Logger::ok(qq[Brand:\t$car_brand]);
        Jum::Logger::ok(qq[Model:\t$car_model]);
        Jum::Logger::ok(qq[Year:\t$car_year]);
        Jum::Logger::ok(qq[Distance:\t$car_distance]);
        Jum::Logger::ok(qq[Status:\t$car_status]);
        Jum::Logger::ok(qq[Body:\t$car_body]);
        Jum::Logger::ok(qq[Price:\t$car_price]);
        
        Jum::Logger::ok(qq[Seller name:\t$car_seller->{seller_name}]);
        Jum::Logger::ok(qq[Seller email:\t$car_seller->{seller_email}]);
        Jum::Logger::ok(qq[Seller phones:\t$car_seller->{seller_phones}]);
        Jum::Logger::ok(qq[Seller city:\t$car_seller->{seller_city}]);
        Jum::Logger::ok(qq[Seller address:\t$car_seller->{seller_address}]);
        
        Jum::Logger::ok(qq[Description:\t$car_description]);

        my $statusID    =   getStatusID($car_status);
        my $modelID     =   getModelID($car_model);
        my $brandID     =   getBrandID($car_brand);
        my $bodyID      =   getBodyID($car_body);
        
        my $complectationID = [];
        
        if($car_complect){
            foreach my $parent (keys %$car_complect){
                Jum::Logger::ok(qq[Complect: $parent => ].join(',', @{$car_complect->{$parent}}));
                push(@$complectationID, getComplectID($parent));
                foreach(@{$car_complect->{$parent}}){
                    push(@$complectationID, getComplectID($_, $parent));
                }
            }
        }
        
        my $sellerID = getSellerID($car_seller);
        
        my $carID = getCarID(
            $task->[0],
            $modelID,
            $brandID,
            $bodyID,
            $statusID,
            $sellerID,
            $car_year,
            $car_price,
            $car_distance,
            $car_description
        );

        foreach(@$complectationID){
            $dbh->do($queries_pool{set_complectation}, undef, $carID, $_);
        }
        
        if($car_options){
            foreach my $option (@$car_options){
                Jum::Logger::ok(qq[Option: $option->{name}\t$option->{value}]);
                my $optionID = getOptionID($option->{name});
                $dbh->do($queries_pool{set_option}, undef, $carID, $optionID, $option->{value});
            }
        }
        
        if($car_images){
            foreach my $image (@$car_images){
                Jum::Logger::notice(qq[Image: $image .. saving]);
                my $imageContent = Jum::Web::Crawler::getURL({href=>$image, referer=>$task->[1]});
                if($imageContent->{retcode} == 0 && $imageContent->{http_code} == 200){
                    writeImage($carID, \$imageContent->{content}, $image);
                    Jum::Logger::ok(qq[Image: $image .. saved!]);
                }
                else{
                    Jum::Logger::error(qq[Cannot save $image - $imageContent->{retcode} $imageContent->{http_code}]);
                }
            }
        }
        
        $dbh->do($queries_pool{set_done}, undef, $task->[0]);
        
        Jum::Logger::ok(qq[Work done on $task->[0] $task->[1]!]);
        
        
    }
    else{
        Jum::Logger::error(qq[Cannot get $task->[0]\t$task->[1]\t$content->{retcode}\t$content->{http_code}]);
        $dbh->do($queries_pool{set_error}, undef, $task->[0]);
    }
    
}

sub writeImage {
    my ($carID, $imageContent, $imageName) = @_;
    if(!-d $pics_folder.$carID){
        mkdir $pics_folder.$carID || die qq[Cannot create $pics_folder$carID];
        chmod(0777, $pics_folder.$carID);
    }
    
    open FF,">$pics_folder$carID/".md5_hex($imageName).q[.jpg] or die "$pics_folder$carID/".md5_hex($imageName).q[.jpg];
    binmode FF;
    print FF $$imageContent;
    close FF;
}

sub getOptionID {
    my $option = shift;
    my $optionID = $dbh->selectrow_array($queries_pool{get_option_id}, undef, $option);
    if(!$optionID){
        $dbh->do($queries_pool{set_option_id}, undef, $option, $option);
        $optionID = $dbh->selectrow_array($queries_pool{get_option_id}, undef, $option);
    }
    return $optionID;
}

sub getStatusID {
    my $status = shift;
    my $statusID = $dbh->selectrow_array($queries_pool{get_status}, undef, $status);
    if(!$statusID){
        $dbh->do($queries_pool{set_status}, undef, $status, $status);
        $statusID = $dbh->selectrow_array($queries_pool{get_status}, undef, $status);
    }
    return $statusID;
}

sub getModelID {
    my $model = shift;
    my $modelID = $dbh->selectrow_array($queries_pool{get_model}, undef, $model);
    if(!$modelID){
        $dbh->do($queries_pool{set_model}, undef, $model, $model);
        $modelID = $dbh->selectrow_array($queries_pool{get_model}, undef, $model);
    }
    return $modelID;
}

sub getBrandID {
    my $brand = shift;
    my $brandID = $dbh->selectrow_array($queries_pool{get_brand}, undef, $brand);
    if(!$brandID){
        $dbh->do($queries_pool{set_brand}, undef, $brand, $brand);
        $brandID = $dbh->selectrow_array($queries_pool{get_brand}, undef, $brand);
    }
    return $brandID;
}

sub getBodyID {
    my $body = shift;
    my $bodyID = $dbh->selectrow_array($queries_pool{get_body}, undef, $body);
    if(!$bodyID){
        $dbh->do($queries_pool{set_body}, undef, $body, $body);
        $bodyID = $dbh->selectrow_array($queries_pool{get_body}, undef, $body);
    }
    return $bodyID;
}

sub getComplectID {
    my ($name, $parent) = @_;
    my $parentID = 0;
    if($parent){
        $parentID = $dbh->selectrow_array($queries_pool{get_complect_parent}, undef, $parent);
        if(!$parentID){
            $dbh->do($queries_pool{set_complect_parent}, undef, $parent, $parent,$parent, $parent);
            $parentID = $dbh->selectrow_array($queries_pool{get_complect_parent}, undef, $parent);
        }
    }
    my $entryID = $dbh->selectrow_array($queries_pool{get_complect_entry}, undef, $name, $parentID);
    if(!$entryID){
        $entryID = $dbh->do($queries_pool{set_complect_entry}, undef, $name, $parentID, $name, $parentID);
        $entryID = $dbh->selectrow_array($queries_pool{get_complect_entry}, undef, $name, $parentID);
    }
    return $entryID;
}


sub getSellerID {
    my $seller_hash = shift;
    my $sellerID = $dbh->selectrow_array(
                                            $queries_pool{get_seller},
                                            undef,
                                            $seller_hash->{seller_name},
                                            $seller_hash->{seller_phones}
                                        );
    if(!$sellerID){
        $dbh->do(
                    $queries_pool{set_seller},
                    undef,
                    $seller_hash->{seller_name},
                    $seller_hash->{is_salon},
                    $seller_hash->{seller_phones},
                    $seller_hash->{seller_url},
                    $seller_hash->{seller_address},
                    $seller_hash->{seller_city},
                    $seller_hash->{seller_email},
                    $seller_hash->{seller_name},
                    $seller_hash->{seller_phones},
                );
        $sellerID = $dbh->selectrow_array(
                                            $queries_pool{get_seller},
                                            undef,
                                            $seller_hash->{seller_name},
                                            $seller_hash->{seller_phones}
                                        );
    }
    
    return $sellerID
}


sub getCarID {
    my (
        $queueID,
        $modelID,
        $brandID,
        $bodyID,
        $statusID,
        $sellerID,
        $car_year,
        $car_price,
        $car_distance,
        $car_description
       ) = @_;
    
    my $carID = $dbh->selectrow_array($queries_pool{get_car}, undef, $queueID);
    if(!$carID){
        $dbh->do(
                $queries_pool{set_car},
                undef,
                $queueID,
                $modelID,
                $brandID,
                $bodyID,
                $statusID,
                $sellerID,
                $car_year,
                $car_price,
                $car_distance,
                $car_description
        );
        $carID = $dbh->selectrow_array($queries_pool{get_car}, undef, $queueID);
    }
    return $carID;
}