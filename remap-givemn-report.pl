#!/usr/bin/env perl

use v5.24;

use strict;
use warnings;
use autodie;

use DateTime;
use Path::Tiny qw( path );
use Text::CSV_XS;

my @givemn_columns = qw(
    transaction_code
    confirmation_code
    donation_date
    donation_time
    first_name
    last_name
    address1
    address2
    city
    state
    zip
    country
    email
    is_anonymous
    form_type
    org_reporting_code
    project_name
    project_reporting_code
    fundraiser_name
    fundraiser_creator_first_name
    fundraiser_creator_last_name
    donation_form_url
    referring_page_url
    gift_was_matched
    recurring_type
    recurring_period
    special_event_tag
    processing_rate
    donation_amount
    donor_paid_fees
    our_fee
    net_amount
    dedication
);

my @contributions_columns = (
    'Email Address',
    'Total Amount',
    'Net Amount',
    'Fee Amount',
    'Date Received',
    'Receipt Date',
    'Transaction ID',
    'Payment Method',
    'Contribution Source',
    'Financial Type',
    'Note',
);

my @individuals_columns = (
    'First Name',
    'Last Name',
    'Email Address',
    'Street Address',
    'Supplemental Address 1',
    'City',
    'State',
    'Postal Code',
    'Country',
    'Mobile Phone',
);

sub main {
    my $in_file = path(shift);

    my $in_fh = $in_file->openr;
    # consume header row
    <$in_fh>;

    my $csv = Text::CSV_XS->new( { eol => "\n" } );

    my $contributions_file = $in_file->parent->child(
        $in_file->basename =~ s/(\..+)$/-contributions$1/r );
    my $contributions_fh = $contributions_file->openw;
    $csv->print( $contributions_fh, \@contributions_columns );

    my $individuals_file = $in_file->parent->child(
        $in_file->basename =~ s/(\..+)$/-individuals$1/r );
    my $individuals_fh = $individuals_file->openw;
    $csv->print( $individuals_fh, \@individuals_columns );

    $csv->column_names(@givemn_columns);

    while ( my $row = $csv->getline_hr($in_fh) ) {
        # Anonymous donations have no info
        next if $row->{is_anonymous} eq 'Yes';

        if ( $row->{dedication} ) {
            say "$row->{first_name} $row->{last_name} made a dedication";
            say "  - $_ = $row->{dedication}";
        }

        s/^\D//
            for grep {defined}
            @{$row}{qw( donation_amount net_amount our_fee )};

        my ( $year, $month, $day ) = split /-/, $row->{donation_date};
        my $date
            = DateTime->new( year => $year, month => $month, day => $day )
            ->ymd;

        $csv->print(
            $contributions_fh,
            [
                @{$row}{
                    qw(
                        email
                        donation_amount
                        net_amount
                        our_fee
                        )
                },
                ($date) x 2,
                $row->{transaction_code},
                'Credit Card',
                'GiveMN',
                'Donation',
                q{},
            ],
        );

        $csv->print(
            $individuals_fh,
            [
                @{$row}{
                    qw(
                        first_name
                        last_name
                        email
                        address1
                        address2
                        city
                        state
                        zip
                        country
                        )
                },
                q{},    # phone
            ],
        );
    }
}

main(@ARGV);
