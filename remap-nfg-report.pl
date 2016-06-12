#!/usr/bin/env perl

use v5.24;

use strict;
use warnings;
use autodie;

use Path::Tiny qw( path );
use Text::CSV_XS;

my @nfg_columns = qw(
    transaction_id
    donation_date
    status
    donation_amount
    donation_frequency
    first_name
    last_name
    email
    phone
    designation
    address1
    address2
    city
    state
    zip
    country
    donor_fee
    our_fee
    net_amount
    page
    source
    campaign
    tracking_code
    disbursement_date
    dedication
    acknowledgement_type
    dedication_name
    dedication_message
    dedication_email
    dedication_city
    dedication_address1
    dedication_address2
    dedication_state
    dedication_zip
    dedication_country
    gift_name
    gift_description
    quantity
    public1
    public2
    match_type
    match_for
    original_date
    original_amount
    is_mobile
    vendor
    model
    platform
    type
    payment_method
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

    my $csv = Text::CSV_XS->new( { eol => "\r\n" } );

    my $contributions_file = $in_file->parent->child(
        $in_file->basename =~ s/(\..+)$/-contributions$1/r );
    my $contributions_fh = $contributions_file->openw;
    $csv->print( $contributions_fh, \@contributions_columns );

    my $individuals_file = $in_file->parent->child(
        $in_file->basename =~ s/(\..+)$/-individuals$1/r );
    my $individuals_fh = $individuals_file->openw;
    $csv->print( $individuals_fh, \@individuals_columns );

    $csv->column_names(@nfg_columns);

    while ( my $row = $csv->getline_hr($in_fh) ) {
        next unless $row->{status} eq 'Successful';

        unless ( grep { $_ =~ /Okay/ } $row->{public1}, $row->{public2} ) {
            say "$row->{first_name} $row->{last_name} is anonymous";
        }

        if ( $row->{acknowledgement_type} ) {
            say "$row->{first_name} $row->{last_name} made a dedication";
            say "  - $_ = $row->{$_}" for qw(
                dedication
                acknowledgement_type
                dedication_name
                dedication_message
                dedication_email
                dedication_city
                dedication_address1
                dedication_address2
                dedication_state
                dedication_zip
                dedication_country
            );
        }

        $csv->print(
            $contributions_fh,
            [
                @{$row}{
                    qw(
                        email
                        donation_amount
                        net_amount
                        our_fee
                        donation_date
                        donation_date
                        transaction_id
                        payment_method
                        )
                },
                "$row->{source} - $row->{campaign}",
                (
                    $row->{campaign} =~ /givezooks/i
                    ? 'Event Fee'
                    : 'Donation'
                ),
                (
                    $row->{donation_frequency}
                    ? "Recurring $row->{donation_frequency} donation"
                    : q{}
                ),
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
                        phone
                        )
                },
            ],
        );
    }
}

main(@ARGV);