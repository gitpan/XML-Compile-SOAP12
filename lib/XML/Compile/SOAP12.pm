# Copyrights 2009 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.06.
use warnings;
use strict;

package XML::Compile::SOAP12;
use vars '$VERSION';
$VERSION = '2.00';

use base 'XML::Compile::SOAP';

use Log::Report 'xml-compile-soap12', syntax => 'SHORT';

use XML::Compile::Util;
use XML::Compile::SOAP::Util;
use XML::Compile::SOAP12::Util;

my %roles =
 ( NEXT     => SOAP12NEXT
 , NONE     => SOAP12NONE
 , ULTIMATE => SOAP12ULTIMATE
 );
my %rev_roles = reverse %roles;

XML::Compile->addSchemaDirs(__FILE__);
XML::Compile->knownNamespace
 ( &SOAP12ENC => '2003-soap-encoding.xsd'
 , &SOAP12ENV => '2003-soap-envelope.xsd'
 , &SOAP12RPC => '2003-soap-rpc.xsd'
 );


sub new($@)
{   my $class = shift;
    (bless {}, $class)->init( {@_} );
}

sub init($)
{   my ($self, $args) = @_;
    $args->{version}     = 'SOAP12';
    $self->SUPER::init($args);

    $self->schemas->importDefinitions( [SOAP12ENC, SOAP12ENV, SOAP12RPC] );
    $self;
}


sub sender($)
{   my ($self, $args) = @_;

    error __x"headerfault does only exist in SOAP1.1"
        if $args->{header_fault};

    $self->SUPER::sender($args);
}

sub roleURI($) { $roles{$_[1]} || $_[1] }

sub roleAbbreviation($) { $rev_roles{$_[1]} || $_[1] }

1;
