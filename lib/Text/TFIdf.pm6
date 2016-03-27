use v6;
use Lingua::EN::Stem::Porter;

module Text::TFIdf {
  sub no-callback ($i, $j) {
    return;
  }
  class Document {
    has Str $.contents;
    has Bool $.trim = False;
    has %!words;
    has $!max = 0;
    has Bool $!built = False;

    method !build () {
      $!built = True;
      if ($.trim) {
        for $.contents.split(/\s+|'!'|'.'|'?'/, :skip-empty) -> $w {
          %!words{porter($w)}++;
          if (%!words > $!max) {
            $!max = %!words;
          }
        }
      } else {
        for $.contents.split(/\s+|'!'|'.'|'?'/, :skip-empty) -> $w {
          %!words{$w}++;
          if (%!words > $!max) {
            $!max = %!words;
          }
        }
      }
    }

    method has-word($word) {
      self!build() unless ($!built);

      my $w = ($.trim) ?? porter($word) !! $word;
      if (%!words{$w}:exists) {
        return 0.5 + (0.5 * (%!words{$w} / $!max));
      } else {
        return 0;
      }
    }
  }

  class TFIdf is export {
    has @!documents;
    has %!vocab;
    has %!idfs;
    has Bool $!built = False;
    has %.stop-list;
    has Bool $.trim = False;

    method !build() {
      if ($!built) {
        return;
      }

      $!built = True;
      my $docs = @!documents.elems;
      for %!vocab.keys() -> $key {
        my $denom = %!vocab{$key};
        %!idfs{$key} = log($docs / $denom);
      }
    }

    method add(Str $doc) is export {
      @!documents.push(Document.new(:contents($doc), :trim($.trim)));

      my %seen;
      $!built = False;

      for $doc.split(/\s+|'!'|'.'|'?'/, :skip-empty) -> $w {
        my $i = ($.trim) ?? porter($w) !! $w;
        unless (%.stop-list{$w.lc}:exists) {
          unless (%seen{$i}:exists) {
            %!vocab{$i}++;
            %seen{$i}++;
          }
        }
      }
    }

    method tfidf(Str $doc, Int $id) is export {
      self!build();

      if ($id < 0 || $id > @!documents.elems) {
        return 0;
      }

      my %seen;
      my $score = 0;
      for $doc.split(/\s+|'!'|'.'|'?'/, :skip-empty) -> $w {
        my $i = ($.trim) ?? porter($w) !! $w;
        unless (%seen{$i}:exists) {
          %seen{$i}++;
          my $idf = %!idfs{$i}:exists ?? %!idfs{$i} !! 0;
          $score += @!documents[$id].has-word($w) * $idf;
        }
      }

      return $score;
    }

    method tfids(Str $doc, &callback = &no-callback)  is export {
      self!build();

      my @tfids;

      my $docs = @!documents.elems - 1;
      for [0..$docs] -> $doc-id {
        my $res = self.tfidf($doc, $doc-id);
        if (&callback) {
          callback($doc-id, $res);
        }
        @tfids.push($res);
      }

      return @tfids;
    }
  }
}
