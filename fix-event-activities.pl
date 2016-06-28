use v5.20;
use strict;
use warnings;

use DBI;

my $dbh = DBI->connect(
    'dbi:mysql:database=civicrm', 'root', undef,
    { RaiseError => 1 },
);

for my $activity (
    @{
        $dbh->selectall_arrayref(
            'SELECT * FROM civicrm_activity WHERE activity_type_id = ? AND subject like ?',
            { Slice => {} },
            5, ' - %',
        )
    }
    ) {

    my $event = $dbh->selectrow_hashref(
        'SELECT * FROM civicrm_event e JOIN civicrm_participant p ON e.id = p.event_id WHERE p.id = ?',
        undef,
        $activity->{source_record_id}
    );

    $dbh->do(
        'UPDATE civicrm_activity SET subject = ?, activity_date_time = ? WHERE id = ?',
        undef,
        "$event->{title} - $event->{start_date}$activity->{subject}",
        $event->{start_date},
        $activity->{id},
    );
}
