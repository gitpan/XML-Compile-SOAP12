# Copyrights 2009-2013 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.01.
use warnings;
use strict;

package XML::Compile::SOAP12;
use vars '$VERSION';
$VERSION = '2.04';

use base 'XML::Compile::SOAP';

use Log::Report 'xml-compile-soap12', syntax => 'SHORT';

use XML::Compile::Util          qw/SCHEMA2001/;
use XML::Compile::SOAP::Util;

use XML::Compile::SOAP12::Util;
use XML::Compile::SOAP12::Operation;

my %roles =
 ( NEXT     => SOAP12NEXT
 , NONE     => SOAP12NONE
 , ULTIMATE => SOAP12ULTIMATE
 );
my %rev_roles = reverse %roles;


sub new($@)
{   my $class = shift;
    (bless {}, $class)->init( {@_} );
}

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->_initSOAP12($self->schemas);
}

sub _initSOAP12($)
{   my ($self, $schemas) = @_;
    return $self
        if exists $schemas->prefixes->{env};

    $schemas->addKeyRewrite('PREFIXES(soap12)');

    $schemas->prefixes
      ( soap12env => SOAP12ENV  # preferred names by spec
      , soap12enc => SOAP12ENC
      , soap12rpc => SOAP12RPC
      , xsd       => SCHEMA2001
      );

    $self;
}

sub version    { 'SOAP12' }
sub envelopeNS { SOAP12ENV }


sub sender($)
{   my ($self, $args) = @_;

    error __x"headerfault does only exist in SOAP1.1"
        if $args->{header_fault};

    $self->SUPER::sender($args);
}

sub roleURI($) { $roles{$_[1]} || $_[1] }

sub roleAbbreviation($) { $rev_roles{$_[1]} || $_[1] }

1;
