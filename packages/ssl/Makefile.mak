################################################################
# Build the SWI-Prolog SSL package for MS-Windows
#
# Author: Jan Wielemaker
# 
# Use:
#	nmake /f Makefile.mak
#	nmake /f Makefile.mak install
################################################################

PLHOME=..\..
!include ..\..\src\rules.mk
PKGDLL=ssl4pl
EXDIR=		$(PKGDOC)\examples\http

#
# Constants below are defined in rules.mk
#
LIB=$(LIB);$(OPENSSLLIBDIR)
INCLUDE=$(INCLUDE);$(OPENSSLINCDIR)

EXAMPLES=	client.pl server.pl https.pl

OBJ=		ssl4pl.obj ssllib.obj

all:		$(PKGDLL).dll

$(PKGDLL).dll:	$(OBJ)
		$(LD) /dll /out:$@ $(LDFLAGS) $(OBJ) $(PLLIB) $(LIBS) \
		ssleay32.lib libeay32.lib

!IF "$(CFG)" == "rt"
install:	all idll
!ELSE
install:	all idll ilib
!ENDIF

idll::
		copy $(PKGDLL).dll "$(BINDIR)"
!IF "$(PDB)" == "true"
		copy $(PKGDLL).pdb "$(BINDIR)"
!ENDIF

ilib::
		copy ssl.pl "$(PLBASE)\library"
		$(MAKEINDEX)

xpce-install::

html-install::
		copy odbc.html "$(PKGDOC)"

install-examples::
		if not exist "$(EXDIR)/$(NULL)" $(MKDIR) "$(EXDIR)"
		@for %f in ($(EXAMPLES)) do @copy %f "$(EXDIR)"
		copy /r etc "$(EXDIR)"

uninstall::
		del "$(PLBASE)\bin\$(PKGDLL).dll"
		del "$(PLBASE)\library\ssl.pl"
		$(MAKEINDEX)

clean::
		-del *.obj *~ 2>nul

distclean:	clean
		-del *.dll *.lib *.exe *.pdb *.ilk 2>nul

