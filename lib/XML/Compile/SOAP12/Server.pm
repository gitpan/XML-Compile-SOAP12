# Copyrights 2009 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.06.
use warnings;
use strict;

package XML::Compile::SOAP12::Server;
use vars '$VERSION';
$VERSION = '2.00';

use base 'XML::Compile::SOAP12', 'XML::Compile::SOAP::Server';

use Log::Report 'xml-compile-soap12', syntax => 'SHORT';


sub prepareServer($)
{   my ($self, $server) = @_;
}

1;
