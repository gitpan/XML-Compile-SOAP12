use ExtUtils::MakeMaker;

use 5.008;

WriteMakefile
 ( NAME	 	=> 'XML::Compile::SOAP12'
 , VERSION	=> '2.00'
 , PREREQ_PM    =>
   { XML::Compile         => 0.99
   , XML::Compile::Tester => 0.03
   , XML::Compile::Cache  => 0.14
   , XML::Compile::SOAP   => '2.00'
   , Log::Report     => 0.17
   , Time::HiRes     => 0

   , Test::More      => 0.54
   , Test::Deep      => 0.095
   , Test::Pod       => '1.00'
   }
 , AUTHOR       => 'Mark Overmeer'
 , ABSTRACT     => 'SOAP version 1.2'
 , LICENSE      => 'perl'
 );

### used by oodist during production of distribution
sub MY::postamble { <<'__POSTAMBLE' }

EXTENDS		= ../XMLCompile:../XMLSOAP:../XMLDaemon:../XMLTester

# for DIST
RAWDIR          = ../public_html/xml-compile-soap12/raw
DISTDIR         = ../public_html/xml-compile-soap12/source
LICENSE         = artistic
SKIP_LINKS	= XML::LibXML

# for POD
FIRST_YEAR      = 2009
EMAIL           = perl@overmeer.net
WEBSITE         = http://perl.overmeer.net/xml-compile/
PODTAIL		= ../XML-shared-podtail
__POSTAMBLE
