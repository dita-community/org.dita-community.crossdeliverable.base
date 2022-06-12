<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xdlink="urn:ns:plugin:org.dita-community.crossdeliverable.base"
  xmlns:relpath="http://dita2indesign/functions/relpath"
  exclude-result-prefixes="xs xdlink relpath"
  version="3.0"
  expand-text="true"
  >
  <!-- =======================================================
       DITA Community Cross-Deliverable Base Implementation
       
       Copyright (c) 2022 DITA Community
       
       Overrides the map reference preprocessing stage to
       add, for each peer-scope map reference, a reference
       to the corresponding as-delivered keydef map, if the
       as-delivered map exists in the configured as-delivered
       map location.
       
       The as-delivered maps are generated separately.

       This aspect of cross-deliverable link handling is
       generic because it is independent of the details
       of the delivery target.
       
       The generation of the as-delivered maps cannot be
       generic because it depends on the  deliverable generation 
       and publishing process details.
       
       The input to this process is the output of the map
       reader. The mapref process implements the resolving
       of map-to-map references.
       
       The base mapref stage is used for both the preprocess
       and preprocess2 pipelines.       
       ======================================================= -->
  
  <xsl:param name="as-delivered-map-dir" as="xs:string" select="'../as-delivered-maps'"/>
  
  <xsl:import href="plugin:org.dita-community.common.xslt:xsl/relpath_util.xsl"/>
  <xsl:import href="plugin:org.dita-community.common.xslt:xsl/dita-support-lib.xsl"/>   
  
  <!--
    OVERRIDE: 
    
    Insert references to as-delivered maps corresponding to peer map references.
              
                  
    -->
  
  <!-- Shallow copy identity transform -->
  <xsl:mode name="xdlink:augment-map"
    on-no-match="shallow-copy"
    default-mode="xdlink:augment-map"
  />
  
  <!-- Handle maps that have peer-scope maprefs in them -->
  <xsl:template match="*[contains-token(@class, 'map/map')][.//*[@format eq 'ditamap'][@scope eq 'peer'][exists(@keyscope)]]">
    <xsl:param name="do-augmentation" as="xs:boolean" select="true()"/>
    
    <xsl:variable name="doDebug" as="xs:boolean" select="true()"/>
    
    <xsl:if test="$doDebug">
      <xsl:message>xdlink: Handling map "{base-uri(.)}" with peer maprefs. do-augmentation: {$do-augmentation}</xsl:message>
    </xsl:if>
    
    <xsl:choose>
      <xsl:when test="$do-augmentation">
        <xsl:if test="$doDebug">
          <xsl:message>xdlink:    Doing augmentation</xsl:message>
        </xsl:if>
        <xsl:variable name="augmented-map" as="document-node()">
          <xsl:document>
            <xsl:sequence select="preceding::node()"/>
            <xsl:copy>
              <xsl:attribute name="xml:base" select="base-uri(.)"/>
              <xsl:sequence select="@*"/>
              <xsl:apply-templates select="node()" mode="xdlink:augment-map">
                <xsl:with-param name="doDebug" as="xs:boolean" tunnel="yes" select="$doDebug"/>
              </xsl:apply-templates>
            </xsl:copy>
            <xsl:sequence select="following::node()"/>
          </xsl:document>
        </xsl:variable>
        
        <xsl:if test="$doDebug">
          <xsl:variable name="base-uri" as="xs:string" select="string(base-uri(.))"/>
          <xsl:variable name="map-uri" as="xs:string" select="relpath:getParent($base-uri) ! relpath:newFile(., relpath:getNamePart($base-uri) || '_augmented.ditamap')"/>
          <xsl:message>xdlink: Augmented map written to "{$map-uri}"</xsl:message>
          <xsl:result-document href="{$map-uri}">
            <xsl:sequence select="$augmented-map"/>
          </xsl:result-document>
        </xsl:if>
        
        <xsl:apply-templates select="$augmented-map" mode="xdlink:augment-map">
          <xsl:with-param name="do-augmentation" as="xs:boolean" select="false()"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="#default">
          <xsl:with-param name="do-augmentation" as="xs:boolean" select="false()"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- For peer-scope maprefs with keyscopes, generate references to the corresponding as-delivered map if found.
    -->
  <xsl:template mode="xdlink:augment-map" match="*[contains-token(@class, 'map/topicref')][exists(@href)][@format eq 'ditamap'][@scope eq 'peer'][exists(@keyscope)]">
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
    
    <xsl:if test="$doDebug">
      <xsl:message>xdlink: Handling map reference to map "{@href}" with key scope "{@keyscope}"</xsl:message>
    </xsl:if>
    
    <xsl:variable name="as-delivered-map-uri" as="xs:string?"
      select="xdlink:getAsDeliveredMapUri(., $as-delivered-map-dir)"
    />
    
    <!-- Generate the map reference to the as-delivered map, which is just a normal 
         submap reference.
         
         Putting the mapref in a topicgroup to ensure that the key scope is preserved.
         There seems to be a bug in 3.7.2 that does not preserve the key scope
         when the mapref is resolved.
      -->
    <topicgroup class="- map/topicref mapgroup-d/topicgroup ">
      <xsl:sequence select="@keyscope"/>
      <mapref class="- map/topicref mapgroup-d/mapref " format="ditamap" 
        href="{$as-delivered-map-uri}"
      >      
        <xsl:sequence select="@xtrf, @xtrc"/>
      </mapref>
    </topicgroup>
    <!-- Do not put out the original map reference because that map should not be available in the current processing
         environment.
      -->
      
    
  </xsl:template>

  <!-- Override: Construct result URI using resolve-uri() -->
  <xsl:template match="*[contains(@class,' map/topicref ')]" mode="mapref">
    <xsl:param name="relative-path" as="xs:string">#none#</xsl:param>
    <xsl:param name="mapref-id-path" as="xs:string*"/>
    <xsl:variable name="linking" as="xs:string?">
      <xsl:choose>
        <xsl:when test="empty(@linking)">
          <xsl:call-template name="inherit">
            <xsl:with-param name="attrib">linking</xsl:with-param>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@linking"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="generate-id(.) = $mapref-id-path">
        <xsl:call-template name="output-message">
          <xsl:with-param name="id" select="'DOTX053E'"/>
          <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="not($linking='none') and @href and not(contains(@href,'#')) and not(@scope = 'peer')">
        <xsl:variable name="update-id-path" select="($mapref-id-path, generate-id(.))"/>
        <xsl:variable name="href" select="resolve-uri(@href, base-uri(.))" as="xs:string?"/>
        <xsl:apply-templates select="document($href)/*[contains(@class,' map/map ')]" mode="#current">
          <xsl:with-param name="parentMaprefKeyscope" select="@keyscope" tunnel="yes"/>
          <xsl:with-param name="relative-path">
            <xsl:choose>
              <xsl:when test="not($relative-path = '#none#' or $relative-path='')">
                <xsl:value-of select="$relative-path"/>
                <xsl:call-template name="find-relative-path">
                  <xsl:with-param name="remainingpath" select="@href"/>
                </xsl:call-template>
              </xsl:when>
              <xsl:otherwise>
                <xsl:call-template name="find-relative-path">
                  <xsl:with-param name="remainingpath" select="@href"/>
                </xsl:call-template>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:with-param>
          <xsl:with-param name="mapref-id-path" select="$update-id-path"/>
        </xsl:apply-templates>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <!--
    Determine the URI for the as-delivered map that corresponds to the map
    referenced by the input map reference element.
    @param mapref Topicref that references the peer map we're getting the as-delivered map URI for.
    @param as-delivered-map-dir The URI of the container that stored as-delivered maps.
    @return The URI of the as-delivered map.
    -->
  <xsl:function name="xdlink:getAsDeliveredMapUri" as="xs:string">
    <xsl:param name="mapref" as="element()"/>
    <xsl:param name="as-delivered-map-dir" as="xs:string"/>
    
    <xsl:variable name="map-name" as="xs:string?"
      select="relpath:getNamePart($mapref/@href)"
    />
    <xsl:variable name="as-delivered-map-path" as="xs:string"
      select="$map-name || '_as-delivered.ditamap'"
    />
    
    <xsl:variable name="result" as="xs:string"
      select="relpath:newFile($as-delivered-map-dir, $as-delivered-map-path)"
    />
    <xsl:sequence select="$result"/>
  </xsl:function>
</xsl:stylesheet>