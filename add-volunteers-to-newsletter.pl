#!/usr/bin/perl

use v5.20;
use strict;
use warnings;
use autodie qw( :all );

use DateTime;
use DateTime::Format::MySQL;
use DBI;
use Email::Address;
use Getopt::Long;

sub main {
    my $span    = 'day';
    my $verbose = 0;
    GetOptions(
        'span:s'  => \$span,
        'verbose' => \$verbose,
    );

    my $dbh = DBI->connect(
        'dbi:mysql:database=civicrm', 'root', undef,
        { RaiseError => 1 },
    );

    my ($group_id) = @{
        $dbh->selectcol_arrayref(
            'SELECT id FROM civicrm_group WHERE name like ?',
            undef,
            'Volunteers%'
        ) // []
    };
    die 'Could not find volunteers group' unless $group_id;

    my $dt = DateTime->today->subtract( $span . 's' => 2 );
    my $sql = <<'EOF';
SELECT cc.first_name, cc.last_name, ce.email
  FROM civicrm_email ce
       JOIN civicrm_contact cc ON ( ce.contact_id = cc.id )
       JOIN civicrm_group_contact cgc ON ( cc.id = cgc.contact_id )
 WHERE cc.created_date >= ?
   AND cgc.group_id = ?
EOF

    my @contacts = @{
        $dbh->selectall_arrayref(
            $sql, undef,
            DateTime::Format::MySQL->format_datetime($dt),
            $group_id,
        ) // []
    };

    my $add;
    for my $c (@contacts) {
        $add .= Email::Address->new( "$c->[0] $c->[1]", $c->[2] );
        $add .= "\n";
    }

    if ($add) {
        if ($verbose) {
            say 'Adding new volunteers to email lists';
            say $add;
        }
        open my $vol, '|-',
            '/usr/lib/mailman/bin/add_members -w n -a n -r - volunteer-newsletter';
        print {$vol} $add;
        close $vol;

        open my $ann, '|-',
            '/usr/lib/mailman/bin/add_members -w n -a n -r - announce';
        print {$ann} $add;
        close $ann;
    }
    else {
        say 'No new volunteers to add to email lists' if $verbose;
    }
}

main();
