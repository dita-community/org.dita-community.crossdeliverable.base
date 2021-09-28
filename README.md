# Open Toolkit Plug-In org.dita-community.crossdeliverable.base

Base preprocessing and related support for basic cross-deliverable addressing implementation.

This plug-in provides base support for implementing cross-deliverable linking in DITA Open Toolkit
using the general technique of overriding cross-deliverable keys with deliverable-specific key definitions
that bind the original keys to where the resources bound to those keys are delivered.

**NOTE:** This approach to cross-deliverable addressing not a complete or general solution. You will need
to implement the details of how to map from keys as authored to deliverable-specific URIs as those
details will always be specific to your delivery details, such as the absolute URIs of the deliverables
as published, the mapping from source URIs to target URIs, etc. This plugin provides the general
framework into which you can plug your implementation details.

## Cross-Deliverable Addressing and DITA Open Toolkit

Cross-deliverable addresses are a feature added in DITA 1.3 ([http://docs.oasis-open.org/dita/dita/v1.3/errata02/os/complete/part3-all-inclusive/archSpec/base/links-between-maps.html#links-between-maps]).

A "cross-deliverable" address is a key reference from a topic used in the context of one root map where the key reference in the topic points to a key defined in a separate root map.

More coloquially, these are usually referred to as "cross-book links" (but of course, DITA content can be used
for much more than books...).

### What is a root map?

In DITA, a root map is a map that is used as the input to some kind of processing, such as producing 
a deliverable. While the set of things one might usefully do with a DITA map is unbounded, we generally
create DITA maps in order to publish the content those maps organize. 

For simplicity of discussion let us stipulate that each root map represents a "publication" of some sort that is then delivered, i.e., a web site of HTML pages, a PDF document, an EPUB, embedded help, or whatever it might be.

Rootmapness is simply a function of how a map is used: a map used one day as a root map may later be
used as a submap of some other map. That is, a map is a root map because you say it is in the moment.

There is no inherent property of a DITA map that identifies it as a root map. 

Some map specializations, such as BookMap, are designed to be used as root maps for specific publication types.
These root maps usually have unique content and organization that is required in order to produce a complete deliverable,
typified by BookMap's book-level titles and metadata. Another example is the DITA for Publishers Publication Map 
map specialization.

In practice, we usually have a set of maps that we have carefully constructed to be root maps,
meaning they are the roots of maps that represent distinct publications, i.e., manuals for specific products
or web pages for part of a larger product. More generally, these "maps that represent publications" represent
the "units of publication" for a given body of content.

Thus, within a given DITA-using environment you probably know exactly which maps are the maps you publish and
therefore the maps that are the root maps to which other publications may need to link.

### "Cross-book" links: Key Scopes and Addressing between root maps

In DITA 1.2, the first version to include keys, each root map was a single key space and there was no defined way to refer 
to keys in another root map.

In DITA 1.3 the "scoped keys" feature was added, which allows any submap or topicref to define a new "key scope" such
that keys defined in one scope are distinct from keys defined in a different scope in the same map. 

#### Key Scopes

Key scopes have names that serve to qualify the names of keys defined within them (except for the implicit key scope
defined by a root map, which can be anonymous).

For example, you might use the scope name "image" for keys used for references to images and separate key scopes for each top-level division ("chapter") in your publication:

Pub-01.ditamap for Publication 1:

```
<map>
  <title>Publication One</title>
  ...
  <topicgroup keyscope="image">
    <topicmeta><navtitle>Keys for images</navtitle></topicmeta>
    <keydef keys="login-dialog" format="png" href="images/login-dialog.png">
      <topicmeta><linktext>The log-in dialog showing two fields: User name and password</linktext></topicmeta>
    </keydef>
  </topicgroup>
  ...
  <topicref keyscope="getting-started" keys="introduction" href="topics/getting-started-intro.dita">  
    <topicref keys="logging-in" href="topics/logging-in.dita"/>
    ...
    <topicref keys="logging-out" href="topics/logging-out.dita"/>
  </topicref>    
  ...
</map>
```

The `@keyscope` attribute on the `<topicgroup>` element establishes a new key scope with the scope name "image".
The `@keyscope` attribute on the `<topicref>` to `getting-started-intro.dita` establishes the key scope 
named "getting-started" for the "getting started" section of this publication. Note that the topicref
also has the key name "introduction", which would otherwise be too general to be used in this way, but
the key scope makes this "introduction" key distinct from any other "introduction" key that might be used
in this map.

From outside the scope "image", keys within the scope can be referred to using the key scope name to qualify the key name (separating the scope name from the key name using "."), i.e.:

```
<fig id="login-dialog">
  <title>Login Dialog</title>
  <image keyref="image.login-dialog"/>
</fig>  
```

Within the key scope "getting-started" topics can refer to other keys in the scope using just the key name:

```
<p>Having logged in you can log out using the logout dialog (see <xref keyref="logging-out"/>).
```

The key definition precidence rules apply to key scopes: For any scope-qualified key, the qualified name can
be overridden by a key definition that occurs earlier in the map.

For example, the author of map `Pub-01.ditamap` could override the effective definition of the key `getting-started.logging-out`
by including a key definition with the key name "getting-started.logging-out" before the definition of the `getting-started`
key scope:

Pub-01.ditamap for Publication 1:

```
<map>
  <title>Publication One</title>
  ...
  <topicgroup keyscope="image">
    <topicmeta><navtitle>Keys for images</navtitle></topicmeta>
    <keydef keys="login-dialog" format="png" href="images/login-dialog.png">
      <topicmeta><linktext>The log-in dialog showing two fields: User name and password</linktext></topicmeta>
    </keydef>
  </topicgroup>
  ...
  <keydef keys="getting-started.logging-out" format="html" scope="external" href="http://example.com/docs/logging-out.html">
    <topicmeta><linktext>Logging out</linktext>
  </keydef>    
  ...
  <topicref keyscope="getting-started" keys="introduction" href="topics/getting-started-intro.dita">  
    <topicref keys="logging-in" href="topics/logging-in.dita"/>
    ...
    <topicref keys="logging-out" href="topics/logging-out.dita"/>
  </topicref>    
  ...
</map>
```

Here, the key definition with the `@keys` value "getting-started.logging-out" overrides the scope-qualified key that occurs 
later in the map. The override happens because the first definition of a given key within the map document (or within a depth-first traversal of the tree of submaps) is the effective key definition.

(Foreshadowing: In this example the override of the key `getting-started.logging-out` binds the key to an external
HTML file, not to another topic.)

#### Linking between root maps: Cross-Deliverable Key References

Key scopes are the key (no pun intended) to authoring cross-deliverable links.

The trick is to associate a key scope with the target root map:

Pub-01.ditamap for Publication 1:

```
<map>
  <title>Publication One</title>
  <mapref keyscope="pub-02" scope="peer" href="Pub-02.ditamap"/>
  <topicgroup keyscope="image">
    ...
  </topicgroup>
  ...
</map>
```

Here, the `@scope` value of "peer" says "this map is a separate root map and the `@keyscope` value
associates the key scope name "pub-02" with this root map.

Using the key scope name "pub-02" you can then refer to keys defined in the map `Pub-02.ditamap`:

```
<p>See <xref keyref="pub-02.troubleshooting-login-failures">Troubleshooting Log-In Failures</xref> 
for details.</p>
```

The key reference `pub-02.troubleshooting-login-failures` is a reference to the key "troubleshooting-login-failures"
in the scope "pub-02". Because the scope name "pub-02" is associated with the peer map `Pub-02.ditamap`
the target key should be defined in the map `Pub-02.ditamap`.

This is a cross-deliverable key reference "as authored", meaning that it is defined as a reference from one
DITA topic used in one root map (`Pub-01.ditamap`) to a topic as used in another root map (`Pub-02.ditamap`).

The reference is unambiguous in the source: there can be at most one effective key with the name "troubleshooting-login-failures"
in the root map `Pub-02.ditamap` and, if that key is defined, there should be no difficulty resolving it to its target.
OxygenXML can do this, for example.

Thus, the author of this reference has made their intention crystal clear: This cross reference is to whatever
is bound to the key "troubleshooting-login-failures" in map `Pub-02.ditamap`. Assuming that at the time
the author creates the reference there is a topic with the key "troubleshooting-login-failures", the
author knows what topic their newly-created cross reference would go to if they published both root maps
right then.

The reference has some interesting aspects:

* The reference is not a *guarantee* that there will be something at the end of the reference in the future.
* The key reference is really a *statement of requirements* by the author of the link that there needs to be something at the end of the reference that serves the purpose served by the thing that was there when the link was created. This is a bit amorphous but there's no avoiding it because of the inherent decoupled nature of DITA content: the author of map `Pub-02.ditamap` can bind the key name "troubleshooting-login-failures" to anything at any time in the future.
  
  Likewise, if the topic that makes the reference is used in some other context, either a different root map or a different key scope in the same map, the key scope name "pub-02" could be bound to something other than the original target topic that the 
  author was linking to when they authored the link.
* If the topic making the reference is used in a different context (for example, it is used in a different map or a map it is used in is itself used from another map), the reference may go from being a cross-deliverable link to a with-in deliverable link. This is entirely a function of how the map that uses the topic is set up—the author of the topic has no direct control over this.

### Publishing Cross-Deliverable Links

The inherent challenge with cross-deliverable links is publishing them.

A single DITA root map can produce an unbounded set of potential deliverables:

* Different deliverable formats from a given root map: PDF, HTML, EPUB, etc.
* Different deliverable configurations from a given root map depending on the active filtering conditions and runtime options.

Thus there cannot be, in the general case, a simple one-to-one mapping between source components (topics) and keys and deliverable anchors. Rather there is a potential one-to-infinite mapping.

Likewise, the same topic or submap may be used in multiple root maps (publications) and used multiple times within the same root map.

Thus there cannot be, in the general case, a simple mapping from topics in isolation (i.e., as documents on a file system or in a content management system) and the deliverables they might be published in.

Compare this DITA reality with DocBook, which does not provide any real re-use facility.

In DocBook, while a given DocBook book can be published to many different deliverables, there is, for each deliverable, a one-to-one mapping between source elements and deliverable components (barring output processing that duplicates things for some reason and filtering that might be applied). Likewise, there is a general expectation that a given DocBook document will result in one deliverable of a give type (HTML, PDF, EPUB, etc.).

More importantly, each element within a DocBook book that could be the target of link has a well-defined location within the DocBook document (because there is no reuse in DocBook). Thus it is practical to maintain a simple element-to-deliverable-anchor mapping in a general DocBook processing environment, which is exactly what the DocBook ilink facility does: It provides a way to use a simple mapping data set to map from elements to the documents they occur in and thus to the corresponding anchors in the deliverables generated from those elements. It also helps that DocBook has a smaller and less complicated processing tool chain which also makes implementing cross-deliverable links easier, because DocBook avoids most of the complexity DITA exposes by providing re-use facilities.

I mention DocBook both because it's an important example of an implementation of cross-deliverable linking and is an environment that many DITA users may be coming from where they used DocBook's cross-book linking features and are wondering why they can't do the same thing in DITA.

Of course the answer is "You can do the same thing in DITA, it's just more challening to implement". But it also requires support for DITA 1.3, which is when cross-deliverable linking based on unambiguous key-based references was added to DITA.

#### Anchors and Links

The DITA standard uses the term "deliverable anchor" (or just "anchor") to mean "a thing in a deliverable you can link to directly using some form of URI reference".

Deliverable anchors include:

* HTML pages (the URL to which an HTML page is published is the page's anchor)
* Elements with @id or @name attributes within HTML pages
* Named anchors in PDF documents (the PDF standard provides a PDF-specific URL fragment identifier syntax for linking to named anchors within PDF documents)
* Addressible components within EPUB documents (the EPUB standard provides an EPUB-specific URI syntax and fragment identifier for linking to things within EPUBs)
* Information components within embedded help, usually using identifiers defined by the software or hardware system the embedded help is for

Every well-defined format for delivering content will have its own addressible things and its own way of addressing them using URI syntax (this wasn't always true, of course, but with the rise of the Internet and HTTP as a unifying protocol, providing URI addressability is a cost of entry for all but the most isolated systems).

DITA provides a fairly rich set of ways to identify and point to things within DITA source:

* All topics must exist in some XML document, which necessarily has identity in the context of the content repository that stores it (file system, git repository, CMS, etc.). Thus topics have guaranteed identity from the combination of the topic's containing document's URI and the topic's @id value. If the topic is the root element of its containing document then the URI of the document is sufficient to identify the topic, but if the topic is not the root then it's @id value must be unique within its containing XML document (because topic IDs are of type ID, which the XML standard requires to be unique within the document that contains them).
* Topics may have (and should have) keys assigned to them by the maps that use the topics. Every root map defines a distinct space of keys (distinct from all other possible root maps) where every effective key is unique within the key space defined by the root map (and unique within any key scopes it might occur in within the root map).
* Non-topic elements within topics may be given @id values that must be (by DITA rules, not XML rules) unique within the topic that contains them (but not within any subtopics that the topic may contain).
* Topics may be given any number of resource IDs (`<resourceid>`), which assign arbitrary identifiers for use by any application. Resource IDs were originally designed to support embedded help requirements by providing a way to capture the help-system-specific ways that topic might be known, but they end up being a powerful way to capture deliverable-specific anchors generally. DITA 2.0 extends the original `<resourceid>` design and refines the semantics to make `<resourceid>` a primary way to explicitly determine deliverable anchors for topics.
* Any DITA element may contain embedded metadata (`<data>` elements) that can serve to identify the element in some way, although any such use of metadata is necessarily a private convention and will not be in terms of any DITA-defined mechanism beyond the simple ability to embed metadata using `<data>` elements.

For a given deliverable, any or all of these identification facilities may be used to construct the anchors used in the deliverable.

For example, the default behavior of DITA Open Toolkit's HTML and HTML5 transforms is to use the source URI of each topic as the basis for the result URI of the HTML files generated from the topic (if there is one) and to use the topic and element IDs as the basis for @id values in the generated HTML. This works (mostly) because there is a natural mapping from topics managed as individual XML documents to individual HTML files. It largely avoids any issues around ID or filename collision as long as the source-to-deliverable mapping is simple and maintains the same (or equivalent) directory structure. But note that this simple approach breaks down in the face of features like @chunk, where multiple individual topics might be combined into a single result HTML document where the @id values must be unique within the entire HTML file, not just within a single topic.

By contrast, the default behavior of DITA Open Toolkit's PDF2 transform is to synthesize new IDs for all result components that are or might be linked to from within the PDF: topics, elements with IDs like figures and tables, or even just any element with an ID. As currently implemented there is no predictable relationship between the source elements and their associated identifiers and the resulting PDF anchor names.

But even in the case of the PDF2 transform, it still knows *during the PDF generation process* what the mapping from source identifiers to PDF anchors is so that it can render links in the source to working links in the resulting PDF.

#### Producting Deliverables with Cross-Deliverable Links

Now consider the challenge of implementing cross-deliverable links. It's easier to see the problem in PDF where the source-to-deliverable anchor mapping is not knowable given only knowledge of the source DITA.

Say you have two root maps, Pub-01.ditamap and Pub-02.ditamap, and there are cross-deliverable links between the topics in both publications, meaning topics in Pub-01.ditamap link to topics in Pub-02.ditamap and visa versa, using the DITA 1.3 cross-deliverable link facility (pointing to scope-qualified keys where the key scope is bound to the target publication's root map as defined in the source publication's map).

You produce the PDF for Pub-01.ditamap. How do you create working PDF-to-PDF links to the PDF Pub-02.ditamap?

At this point you can't because you haven't even produced the PDF for Pub-02.ditamap yet, and we've established that you can't predict the PDF anchors from the DITA source (because of the way the PDF2 transform generates the internal PDF anchors).

So at a minumum you must first generate the PDF for Pub-02.ditamap so you can then capture in some way the source-to-deliverable-anchor mapping for Pub-02's PDF that will then allow you to produce working cross-deliverable links from Pub-01 PDF to Pub-02 PDF.

But to generate Pub-02.ditamap's PDF you have to be able to resolve cross-deliverable links from Pub-02 to Pub-01.

So first you need to generate the PDFs for both root maps, knowing that both will be incomplete, capture the source-to-deliverable-anchor mapping for both, then regenerate both PDFs again to produce PDFs with good PDF-to-PDF links.

That still leaves open the detail of capturing the source-to-deliverable anchor mapping: how to do that? The PDF2 transform as implemented in OT 3.6.1 does not provide that mapping today The PDF transform does in fact retain full knowledge of the original resolved map and topics, so it's possible to capture the mapping, but that would be a customization to the base PDF2 transform.

So you implement the extension to the PDF2 transform that captures the source-to-deliverable-anchor mapping: what form does that mapping take?

There are any number of useful ways the mapping could be stored:

* As a simple text file (i.e., CSV, JSON, or XML) with columns or fields for source element, navigation title, and result anchor
* As tables or similar data structures in a database system with the same source, title, and result anchor fields
* As a set of key definitions that map the source keys to the deliverable anchors those keys become

Regardless of what format you choose as an implementation decision, all your deliverable production implementations then need to be able to access and understand the data. For example, you might implement a small REST service that provides access to the anchor information stored in a database or you might implement XSLT libraries to read the data files or you might just use the generated key definitions.

This plug-in uses the key definition approach because it's the easiest thing to implement.

With this approach, to generate deliverables with cross-deliverable links you do the first pass and as output for each root map you generate a set of key definitions that map the relevant source keys to the external-scope URIs of the deliverable anchors those keys became. I.e., given a source topicref like this:

```
<map>
  <title>Publication One</title>
  ...
  <topicref keys="chapter-one" href="topics/sometopic-0001.dita"/>
  ...
</map>
```

You would generate a deliverable topicref like this:

```
<map>
  <title>PDF Deliverable topicrefs for Publication One</title>
  ...
  <topicref keys="chapter-one" scope="external" format="pdf" 
     href="pub-01.pdf#anchor-012345">
    <topicmeta><navtitle>Chapter 1: Getting Started</navtitle>
  </topicref>
  ...
</map>
```

You then perform the second pass, including the deliverable-specific maps for each of the *other* root maps into the root map being processed. 

By putting the topicrefs in the root map before any other key-defining topicrefs they are guaranteed to override the original keydefs by the rules of key precedence (first and highest definition of a given key wins).

HTML processing would work the same way: You process both root maps in a first pass to generate the external-scope keys that represent the HTML constructs each key became and then process them again in a second pass to produce complete HTML files with working cross-deliverable links.

The details of how you generate these deliverable keydefs is dependent on a number of variables, including:

* Is it possible to predict the result URL of a given key (or non-topic element addressed by key) given only knowledge of the DITA source? If so, it may be possible to generate the deliverable maps directly without the need to do a full deliverable generation pass. For example, if there is a direct mapping from your DITA source file names and folder structure to the HTML filenames and folder structure. This is often the case for HTML deliverables.
* Can the code that generates deliverable anchors be extracted from the deliverable processor? If so, you again might be able to generate the deliverable maps directly using just the anchor generation code.

In the worst case, you have to extend the deliverable producing code to generate the deliverable anchor keydefs as part of the larger output generation process. Remember that you have to take run-time parameters, such as the filters applied, into account.

For the second pass, you could of course manually include the deliverable keydefs in root map as an authoring action, but that would be tedious and would have to be undone once the deliverable was produced.

The automatic solution is to modify the Open Toolkit preprocessing so that it inserts the deliverable keydefs into the map before the map's key space is constructed, allowing normal key processing to do the rest.

#### Determing Which Target Deliverable a Given Source Deliverable Links To

Another potential complicating factor is determining for a given link what deliverable that link should point to in the context of a given source deliverable.

We typically assume that all links will be like-to-like, meaning HTML deliverables will link to HTML deliverables, PDF deliverables will link to PDF deliverables, etc.

That's a typical case and a convenient simplifying assumption but it's definitely not the only choice.

For example, there may be content that is only published in one format and thus other deliverable formats will need to link to it (i.e., API documentation that is only published in HTML linked to from PDF deliverables or PDF deliverables that are linked to from HTML deliverables, where the PDF may be the authoritative version of a given document or maybe the PDF is a printable job aid or something).

In any case, it will likely be necessary to control on a per-link or per-target basis what the target deliverable should be.

This is a non-trivial configuration management challenge and there's no obvious good answer to it.

However, if you are using deliverable key definitions you can control the mapping simply by controlling which deliverable-specific key definitions you include for a given deliverable target. How you do the selection is the configuration management challenge. It could be something you do manually or it could be driven by some business rules you implement against metadata put on the source topicrefs or on topics or whatever it might be.

The point is you will likely need to provide a way to do this, so be prepared.

This plug-in starts with the simplest use case: like links to like. More sophisticated requirements will require more sophisticated solutions.

Note too that the solution details will be highly dependent on your local requirements, so again, a general solution is difficult to implement, certainly not in a simple way.


## Branching Strategy

The `develop` branch is the default branch, to which active development is committed.

The `main` branch reflects "released" code that has been tested and verified.

Use feature branches to develop new code and commit via pull requests.
