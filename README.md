FaveHarvest
===========

Harvest Your Favorited Tweets.

Prerequisites
-------------

The setup I use stores tweet data using MySQL and Perl's MySQL library. Changes would 
be necessary to use other engines, such as PostgreSQL or SQLite, but it shouldn't require 
much work.

I use the feature "say", which works like "print" but appends a newline to the end of the
line. This is a newer part of Perl, which requires a newer Perl than you might have. 
Without stress-testing, I'd guess that this won't work with Perls older than 5.10, 
but as the community supports only 5.16 and newer, I think, and the most recently 
released version is 5.20, this hopefully should not be a problem.

Many of the modules I use are part of Perl's core and are distributed with Perl itself.
DateTime, DBI, IO::Interactive, LWP::UserAgent, Net::Twitter, and YAML. You can use
either CPAN or your distribution's package manager to install these modules.

Configuration
-------------

Because Twitter uses OAuth for their authentication, you need to get your own 
Consumer Key and Secret from Twitter at https://apps.twitter.com/. The Consumer 
Key is control at the application level, and each twitter feed you harvest for 
favorites will have it's own token set as well. These are the first lines of your
.twitter.cnf file. I have included a sample .twitter.cnf file.

The first time you use this tool with a given user, it will not start the harvest,
but instead it will set up and store the OAuth keys. This will require a web browser
where you are logged in to Twitter as the user desired.

Because I hate having usernames and passwords in my code, and I want to make the 
my interaction with databases as simple as possible, I have written two modules,
DB.pm and MyDB.pm, which are in the lib directory of this but should be in your
$ENV{HOME}/lib directory. This uses YAML to store the access information. A sample
my.yaml file is included as well.

The database schema I use is also included as twitter_favorites.sql.

Usage
-----

    twitter_favorites.pl -u <screen_name_without_at_sign>

    twitter_favorites_harvester.pl -u <screen_name_without_at_sign>


There are two bundled programs: twitter_favorites.pl and twitter_favorites_harvester.pl.
The main difference is that favorites starts at the top of list and exits if it finds an
already-entered favorite tweet, while harvester will go until it's hit the end of the 
list, skipping past already-entered favorite tweets.

Twitter rate-limits access to it's APIs in an attempt to keep the fail whale at bay, so 
my program only picks up a new set of up to 20 favorites every five minutes.

Data
----

Your data is stored in your database. Getting it out like in the form you need it is
up to you.

You can use the following query, for example, to list your top ten favorited twitter
users:

    select user_screen_name screen_name 
        , count(*) count 
    from twitter_favorites 
    group by screen_name 
    order by count 
    desc limit 10
