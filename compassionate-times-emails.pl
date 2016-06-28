use v5.20;
use strict;
use warnings;

use DBI;
use DateTime::Format::MySQL;
use DateTime;
use Getopt::Long;
use Path::Class qw( file );

my %opts = (
    years  => 2,
    amount => 15,
);

GetOptions(
    'years:s'  => \$opts{years},
    'amount:s' => \$opts{amount},
);

my $cutoff = DateTime::Format::MySQL->format_datetime(
    DateTime->today->subtract( years => $opts{years} ) );

my %ignore = ignored_emails();
my @remove;

my $sql = <<'EOF';
SELECT email.email, SUM(contribution.total_amount) AS total, contact.do_not_email, contact.is_opt_out
FROM   civicrm_contact AS contact
       JOIN civicrm_contribution AS contribution
           ON contact.id = contribution.contact_id
       JOIN civicrm_email AS email
           ON contact.id = email.contact_id AND email.is_primary = 1
WHERE contribution.is_test = 0
  AND contribution.contribution_status_id  = 1
  AND contribution.receive_date >= ?
  AND contact.is_deleted = 0
GROUP BY contact.id
HAVING total >= ?
EOF

my $dbh = DBI->connect(
    'dbi:mysql:database=civicrm', 'root', undef,
    { RaiseError => 1 },
);

for my $contact (
    @{ $dbh->selectall_arrayref( $sql, undef, $cutoff, $opts{amount} ) } ) {

    if ( $ignore{ lc $contact->[0] } || $contact->[2] || $contact->[3] ) {
        push @remove, $contact->[0];
    }
    else {
        say $contact->[0];
    }
}

say q{};
say '-------------------------------------------';
say '*Remove*';
say '-------------------------------------------';
say $_ for @remove;
say q{};

sub ignored_emails {
    return
        map { $_ => 1 }
        file('./compassionate-times-excluded')->slurp( chomp => 1 );
}
