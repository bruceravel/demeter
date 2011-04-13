;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; use skeleton-mode (http://www.emacswiki.org/emacs/SkeletonMode)
;;; and abbrev-mode (http://www.emacswiki.org/emacs/AbbrevMode) to
;;; make life a little easier when writing Demeter scripts.
;;;
;;; these define little templates for Data, Path, Fit, and GDS objects
;;;
;;; type, for example, DData<space> and a template for a Data object
;;; will be inserted
;;;
;;;    DData : Data object
;;;    DPath : Path object
;;;    DFit  : Fit object
;;;    DGDS  : attay of GDS objects using simpleGDS
;;;
;;; to use, put this in your .emacs file:
;;;     (load-file "/path/to/demeter-skeletons.el")
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(add-hook 'cperl-mode-hook (lambda () (abbrev-mode 1)))
(add-hook 'perl-mode-hook (lambda () (abbrev-mode 1)))

(define-skeleton demeter-data-skeleton
  "Insert a Demeter Path object definition"
  nil
  \n >
  "my $data = Demeter::Data->new(name     => ,  cv       => ,"
  \n >
  "fft_kmin =>  , fft_kmax => ,"
  \n >
  "bft_rmin =>  , bft_kmax => ,"
  \n >
  "fit_k1   => 1, fit_k2   => 1, fit_k3 => 1,"
  \n >
  ");"
)

(define-abbrev cperl-mode-abbrev-table "DData"
  "" 'demeter-data-skeleton)

(define-skeleton demeter-path-skeleton
  "Insert a Demeter Path object definition"
  nil
  \n >
  "my $path = Demeter::Path->new(name   => ,"
  \n >
  "data   => ,"
  \n >
  "sp     => ,"
  \n >
  "s02    => ,"
  \n >
  "e0     => ,"
  \n >
  "delr   => ,"
  \n >
  "sigma2 => ,"
  \n >
  ");"
)

(define-abbrev cperl-mode-abbrev-table "DPath"
  "" 'demeter-path-skeleton)

(define-skeleton demeter-fit-skeleton
  "Insert a Demeter Fit object definition"
  nil
  \n >
  "my $fit = Demeter::Fit->new(data  => ,"
  \n >
  "paths => ,"
  \n >
  "gds   => ,"
  \n >
  ");"
)

(define-abbrev cperl-mode-abbrev-table "DFit"
  "" 'demeter-fit-skeleton)

(define-skeleton demeter-gds-skeleton
  "Insert a Demeter Fit object definition"
  nil
  \n >
  "my @gds = (Demeter->simpleGDS(\"guess a = \"),"
  \n >
  "Demeter->simpleGDS(\"guess b = \"),"
  \n >
  ");"
)

(define-abbrev cperl-mode-abbrev-table "DGDS"
  "" 'demeter-gds-skeleton)


