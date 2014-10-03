#!/usr/bin/env perl

use feature qw{ say } ;
use strict ;
use utf8 ;
use Carp ;
use Data::Dumper ;
use DateTime ;
use Encode 'decode' ;
use Getopt::Long ;
use IO::Interactive qw{ interactive } ;
use LWP::UserAgent ;
use Net::Twitter ;
use YAML qw{ DumpFile LoadFile } ;
use open ':std', ':encoding(UTF-8)' ;
binmode STDOUT, ':utf8' ;

use lib '/home/jacoby/lib' ;
use DB ;

my $start = 1 ;
$start = 162 ;

my $config = config() ;
read_favorites( $config ) ;
exit ;

# ========= ========= ========= ========= ========= ========= =========
sub read_favorites {
    my $config = shift ;
    my $twit   = Net::Twitter->new(
        traits          => [ qw/API::RESTv1_1/ ],
        consumer_key    => $config->{ consumer_key },
        consumer_secret => $config->{ consumer_secret },
        ssl             => 1,
        ) ;
    if ( $config->{ access_token } && $config->{ access_token_secret } ) {
        $twit->access_token( $config->{ access_token } ) ;
        $twit->access_token_secret( $config->{ access_token_secret } ) ;
        }
    unless ( $twit->authorized ) {
        # You have no auth token
        # go to the auth website.
        # they'll ask you if you wanna do this, then give you a PIN
        # input it here and it'll register you.
        # then save your token vals.
    
        say "Authorize this app at ", $twit->get_authorization_url,
            ' and enter the PIN#' ;
        my $pin = <STDIN> ;    # wait for input
        chomp $pin ;
        my ( $access_token, $access_token_secret, $user_id, $screen_name ) =
            $twit->request_access_token( verifier => $pin ) ;
        save_tokens( $user, $access_token, $access_token_secret ) ;
        exit ;
        }

    # my @favs; 
    for ( my $page = $start ; ; ++$page ) {
        say { interactive } qq{\tPAGE $page} ;
        my $r = $twit->favorites( { 
            page => $page 
            } ) ;
        last unless @$r ;
        for my $fav ( @$r ) {
            store_tweet( $fav ) ;
            }
        sleep 60 * 5 ; # five minutes
        }
    }

# ========= ========= ========= ========= ========= ========= =========
sub store_tweet {
    my $tweet = shift ;
    my $sql =<<SQL;
    INSERT INTO twitter_favorites (
        twitter_id , text , created , retweeted , 
        user_id , user_name , user_screen_name
        )
    VALUES (
        ? , ? , ? , ? , 
        ? , ? , ?
        ) ;
SQL
    my @input ;
    push @input , $tweet->{ id } ; # twitter_id
    push @input , $tweet->{ text } ; # text 
    push @input , handle_date( $tweet->{ created_at } ) ; # created
    push @input , $tweet->{ truncated } ; # retweeted 
    push @input , $tweet->{ user }->{ id } ; # user id 
    push @input , $tweet->{ user }->{ name } ; # user id 
    push @input , $tweet->{ user }->{ screen_name } ; # user id 
    my $test = test_database( $tweet->{ id } ) ;
    say { interactive } $tweet->{ id } ;
    if ( ! $test ) {
        my $r = db_do( $sql , @input ) ;
        say { interactive } join "\t" , $r , $input[ 0 ] , $input[ -1 ] ;
        } 
    else {
        say { interactive } join "\t" , '' , 'done' ;
        }
    }

# ========= ========= ========= ========= ========= ========= =========
sub test_database {
    my $tweet_id = shift ;
    my $sql = <<SQL;
        SELECT COUNT(*) FROM twitter_favorites WHERE twitter_id = ?
SQL
    my $output = db_arrayref( $sql , $tweet_id ) ;
    return $output->[0]->[0] ;
    }

# ========= ========= ========= ========= ========= ========= =========
sub read_direct_messages {
    my $config = shift ;
    my $twit   = Net::Twitter->new(
        traits          => [ qw/API::RESTv1_1/ ],
        consumer_key    => $config->{ consumer_key },
        consumer_secret => $config->{ consumer_secret },
        ssl             => 1,
        ) ;
    if ( $config->{ access_token } && $config->{ access_token_secret } ) {
        $twit->access_token( $config->{ access_token } ) ;
        $twit->access_token_secret( $config->{ access_token_secret } ) ;
        }
    unless ( $twit->authorized ) {
        croak( "Not Authorized" ) ;
        }
    my $direct_messages = $twit->direct_messages(  ) ;
    for my $dm ( @$direct_messages ) {
        my $sender = $dm->{ sender } ;
        my $screen_name = $sender->{ screen_name } ;
        my $name = $sender->{ name } ;
        my $icon = $sender->{ profile_image_url } ;
        my $date = handle_date( $dm->{ created_at } ) ;
        my $today = today() ;
        if ( $today eq $date ) {
            my $title = qq{From $name (\@$screen_name)} ;
            my $body = $dm->{ text } ;
            my $icon_path = '/home/jacoby/Pictures/Icons/twitter_logo_blue.png' ;
            notify( $title, $body , $icon_path ) ;
            }
        # say Dumper $sender ;
        }
    }

# Grabs sender icon from Twitter
sub harvest_icon {
    my $screen_name = shift ;
    my $icon = shift ;
    my $suffix = ( split m{\.} , $icon )[-1] ;
    my $icon_dir = '/home/jacoby/Pictures/Icons/Twitter/' ; 
    my $twitter_avatar = join '.' , 'twitter' , lc $screen_name , $suffix ;
    my $twitter_avatar_full = $icon_dir . $twitter_avatar ;
    if ( ! -f $twitter_avatar_full ) {
        say 'No avatar' ;
        my $agent = LWP::UserAgent->new( ) ; #ssl_opts => { verify_hostname => 0 } ) ;
        my $request = new HTTP::Request( 'GET', $icon ) ;
        my $response = $agent->request( $request ) ;
        if ( $response->is_success ) {
            open my $fh , '>' , $twitter_avatar_full ;
            print $fh $response->content ;
            close $fh ;
            }
        }
    return $twitter_avatar_full ;
    # return '/home/jacoby/Pictures/Icons/icon-dilbert-unix.png' ;
    }

# Gets today's date in YMD for comparison
sub today {
    my $today  = DateTime->now() ;
    $today->set_time_zone( 'floating' ) ;
    return $today->ymd() ;
    }

# Gets DM date, for comparison
sub handle_date {
    my $twitter_date = shift ;
    my $months = {
        Jan => 1 ,
        Feb => 2 ,
        Mar => 3 ,
        Apr => 4 ,
        May => 5 ,
        Jun => 6 ,
        Jul => 7 ,
        Aug => 8 ,
        Sep => 9 ,
        Oct => 10 ,
        Nov => 11 ,
        Dec => 12 , 
        } ;
    my @twitter_date = split m{\s+} , $twitter_date ;
    my $year = $twitter_date[5] ;
    my $month = $months->{ $twitter_date[1] } ;
    my $day = $twitter_date[2] ;
    my $t_day = DateTime->new(
        year => $year ,
        month => $month ,
        day => $day ,
        time_zone => 'floating'
        ) ;
    return $t_day->ymd() ;
    }

# Handles the actual notification, using Linux's notify-send
sub notify {
    my $title = shift ;
    my $body  = shift ;
    my $icon  = shift ;
    say $icon ;
    $body = $body || '' ;
    $icon = $icon || $ENV{HOME} . '/Pictures/Icons/icon_black_muffin.jpg' ;
    `notify-send "$title" "$body" -i $icon  ` ;
    }

## ========= ========= ========= ========= ========= ========= =========
#sub update_profile {
#    my $config = shift ;
#    my $twit   = Net::Twitter->new(
#        traits          => [ qw/API::RESTv1_1/ ],
#        consumer_key    => $config->{ consumer_key },
#        consumer_secret => $config->{ consumer_secret },
#        ssl             => 1,
#        ) ;
#    if ( $config->{ access_token } && $config->{ access_token_secret } ) {
#        $twit->access_token( $config->{ access_token } ) ;
#        $twit->access_token_secret( $config->{ access_token_secret } ) ;
#        }
#    unless ( $twit->authorized ) {
#        croak( "Not Authorized" ) ;
#        }
#
#    #unless ( $twit->authorized ) {
#    #
#    #    # You have no auth token
#    #    # go to the auth website.
#    #    # they'll ask you if you wanna do this, then give you a PIN
#    #    # input it here and it'll register you.
#    #    # then save your token vals.
#    #
#    #    say "Authorize this app at ", $twit->get_authorization_url,
#    #        ' and enter the PIN#' ;
#    #    my $pin = <STDIN> ;    # wait for input
#    #    chomp $pin ;
#    #    my ( $access_token, $access_token_secret, $user_id, $screen_name ) =
#    #        $twit->request_access_token( verifier => $pin ) ;
#    #    save_tokens( $user, $access_token, $access_token_secret ) ;
#    #    }
#
#    my @params ;
#    my $params ;
#    for my $p ( qw{ name url location description include_entities } ) {
#        $params->{ $p } = $config->{ $p } if $config->{ $p } ;
#        #my $v = $config->{ $p } ;
#        #push @params , $v ;
#        }
#    #push @params , 1 ;
#    $params->{ skip_status } = 1 ;
#
#    if ( $twit->update_profile( $params ) ) {
#        say 'OK' ;
#        }
#    }

# ========= ========= ========= ========= ========= ========= =========
sub config {
    my $config_file = $ENV{ HOME } . '/.twitter_dm.cnf' ;
    my $data        = LoadFile( $config_file ) ;

    my $config ;
    GetOptions(
        'user=s'        => \$config->{ user },
        # 'description=s' => \$config->{ description },
        # 'location=s'    => \$config->{ location },
        # 'name=s'        => \$config->{ name },
        # 'web=s'         => \$config->{ url },
        'help'          => \$config->{ help },
        ) ;
    $config->{ user } = 'jacobydave' ;
    if (   $config->{ help }
        || !$config->{ user }
        || !$data->{ tokens }->{ $config->{ user } } ) {
        say $config->{ user } || 'no user' ;
        croak qq(nothing) ;
        }

    for my $k ( qw{ consumer_key consumer_secret } ) {
        $config->{ $k } = $data->{ $k } ;
        }

    my $tokens = $data->{ tokens }->{ $config->{ user } } ;
    for my $k ( qw{ access_token access_token_secret } ) {
        $config->{ $k } = $tokens->{ $k } ;
        }
    return $config ;
    }

#========= ========= ========= ========= ========= ========= =========
sub restore_tokens {
    my ( $user ) = @_ ;
    my ( $access_token, $access_token_secret ) ;
    if ( $config->{ tokens }{ $user } ) {
        $access_token = $config->{ tokens }{ $user }{ access_token } ;
        $access_token_secret =
            $config->{ tokens }{ $user }{ access_token_secret } ;
        }
    return $access_token, $access_token_secret ;
    }

#========= ========= ========= ========= ========= ========= =========
sub save_tokens {
    my ( $user, $access_token, $access_token_secret ) = @_ ;
    $config->{ tokens }{ $user }{ access_token }        = $access_token ;
    $config->{ tokens }{ $user }{ access_token_secret } = $access_token_secret ;

    #DumpFile( $config_file, $config ) ;
    return 1 ;
    }
