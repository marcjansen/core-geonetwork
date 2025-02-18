<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:gco="http://www.isotc211.org/2005/gco"
	xmlns:gmd="http://www.isotc211.org/2005/gmd"
  xmlns:gmx="http://www.isotc211.org/2005/gmx"
	xmlns:gml="http://www.opengis.net/gml" 
	xmlns:srv="http://www.isotc211.org/2005/srv"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:util="java:org.fao.geonet.util.XslUtil"
	xpath-default-namespace="http://www.isotc211.org/2005/gmd"
  xmlns:gn-fn-index="http://geonetwork-opensource.org/xsl/functions/index"
  xmlns:schema-org-fn="http://geonetwork-opensource.org/xsl/functions/schema-org"
	exclude-result-prefixes="#all"
	version="2.0">

  <!--
  Convert an ISO19139 records in JSON-LD format


  This JSON-LD can be embeded in an HTML page using
  ```
  <html>
    <script type="application/ld+json">
     {json-ld}
    </script>
  </html>
  ```


   Based on https://schema.org/Dataset


   Tested with https://search.google.com/structured-data/testing-tool

   TODO: Add support to translation https://bib.schema.org/workTranslation
   -->



  <!-- Used for json escape string -->
  <xsl:import href="common/index-utils.xsl"/>


  <!-- Convert a hierarchy level into corresponding
  schema.org class. If no match, return http://schema.org/Thing

  Prefix are usually 'http://schema.org/' or 'schema:'.
   -->
  <xsl:function name="schema-org-fn:getType" as="xs:string">
    <xsl:param name="type" as="xs:string"/>
    <xsl:param name="prefix" as="xs:string"/>

    <xsl:variable name="map" as="node()+">
      <entry key="dataset" value="Dataset"/>
      <entry key="series" value="Dataset"/>
      <entry key="service" value="WebAPI"/>
      <entry key="application" value="SoftwareApplication"/>
      <entry key="collectionHardware" value="Thing"/>
      <entry key="nonGeographicDataset" value="Dataset"/>
      <entry key="dimensionGroup" value="TechArticle"/>
      <entry key="featureType" value="Dataset"/>
      <entry key="model" value="TechArticle"/>
      <entry key="tile" value="Dataset"/>
      <entry key="fieldSession" value="Project"/>
      <entry key="collectionSession" value="Project"/>
    </xsl:variable>

    <xsl:variable name="match"
                  select="$map[@key = $type]/@value"/>

    <xsl:variable name="prefixedBy"
                  select="if ($prefix = '') then 'http://schema.org/' else $prefix"/>

    <xsl:value-of select="if ($match != '')
                          then concat($prefixedBy, $match)
                          else concat($prefixedBy, 'Thing')"/>
  </xsl:function>


  <!-- Define the root element of the resources
      and a catalogue id. -->
  <!--<xsl:param name="baseUrl"
             select="'https://data.geocatalogue.fr/id/'"/>
     <xsl:variable name="catalogueName"
             select="'/geocatalogue'"/>
  -->
  <xsl:param name="baseUrl"
             select="util:getSettingValue('nodeUrl')"/>
  <xsl:variable name="catalogueName"
                select="''"/>

  <!-- Schema.org document can't really contain
  translated text. So we can produce the JSON-LD
  in one of the language defined in the metadata record.

  Add the lang parameter to the formatter URL `?lang=fr`
  to force a specific language. If translation not available,
  the default record language is used.
  -->
  <xsl:param name="lang"
             select="''"/>


  <!-- TODO: Convert language code eng > en_US ? -->
  <xsl:variable name="defaultLanguage"
                select="//gmd:MD_Metadata/gmd:language/*/@codeListValue"/>

  <xsl:variable name="requestedLanguageExist"
                select="$lang != ''
                        and count(//gmd:MD_Metadata/gmd:locale/*[gmd:languageCode/*/@codeListValue = $lang]/@id) > 0"/>

  <xsl:variable name="requestedLanguage"
                select="if ($requestedLanguageExist)
                        then $lang
                        else //gmd:MD_Metadata/gmd:language/*/@codeListValue"/>

  <xsl:variable name="requestedLanguageId"
                select="concat('#', //gmd:MD_Metadata/gmd:locale/*[gmd:languageCode/*/@codeListValue = $requestedLanguage]/@id)"/>



  <xsl:template name="getJsonLD"
                mode="getJsonLD" match="gmd:MD_Metadata">

	{
		"@context": "http://schema.org/",
    <xsl:choose>
      <xsl:when test="gmd:hierarchyLevel/*/@codeListValue != ''">
		    "@type": "<xsl:value-of select="schema-org-fn:getType(gmd:hierarchyLevel/*/@codeListValue, 'schema:')"/>",
      </xsl:when>
      <xsl:otherwise>
        "@type": "schema:Dataset",
      </xsl:otherwise>
    </xsl:choose>
    <!-- TODO: Use the identifier property to attach any relevant Digital Object identifiers (DOIs). -->
		"@id": "<xsl:value-of select="concat($baseUrl, 'dataset/', gmd:fileIdentifier/*/text())"/>",
		"includedInDataCatalog":["<xsl:value-of select="concat($baseUrl, 'catalog/', $catalogueName)"/>"],
    <!-- TODO: is the dataset language or the metadata language ? -->
    "inLanguage":"<xsl:value-of select="$requestedLanguage"/>",
    <!-- TODO: availableLanguage -->
    "name": <xsl:apply-templates mode="toJsonLDLocalized"
                                 select="gmd:identificationInfo/*/gmd:citation/*/gmd:title"/>,

    <!-- An alias for the item. -->
    <xsl:for-each select="gmd:identificationInfo/*/gmd:citation/*/gmd:alternateTitle">
      "alternateName": <xsl:apply-templates mode="toJsonLDLocalized"
                                                  select="."/>,
    </xsl:for-each>

    <xsl:for-each select="gmd:identificationInfo/*/gmd:citation/*/gmd:date[gmd:dateType/*/@codeListValue='creation']/*/gmd:date/*/text()">
		  "dateCreated": "<xsl:value-of select="."/>",
    </xsl:for-each>
    <xsl:for-each select="gmd:identificationInfo/*/gmd:citation/*/gmd:date[gmd:dateType/*/@codeListValue='revision']/*/gmd:date/*/text()">
		"dateModified": "<xsl:value-of select="."/>",
    </xsl:for-each>
    <xsl:for-each select="gmd:identificationInfo/*/gmd:graphicOverview/*/gmd:fileName/*[. != '']">
		"thumbnailUrl": "<xsl:value-of select="."/>",
    </xsl:for-each>

		"description": <xsl:apply-templates mode="toJsonLDLocalized"
                                        select="gmd:identificationInfo/*/gmd:abstract"/>,

    <!-- TODO: Add citation as defined in DOI landing pages -->
    <!-- TODO: Add identifier, DOI if available or URL or text -->

    <xsl:for-each select="gmd:identificationInfo/*/gmd:citation/*/gmd:edition/gco:CharacterString[. != '']">
      "version": "<xsl:value-of select="."/>",
    </xsl:for-each>


    <!-- Build a flat list of all keywords even if grouped in thesaurus. -->
    "keywords":[
      <xsl:for-each select="gmd:identificationInfo/*/gmd:descriptiveKeywords/gmd:MD_Keywords/gmd:keyword">
        <xsl:apply-templates mode="toJsonLDLocalized"
                             select=".">
          <xsl:with-param name="asArray" select="false()"/>
        </xsl:apply-templates>
        <xsl:if test="position() != last()">,</xsl:if>
      </xsl:for-each>
		],


    <!--
    TODO: Dispatch in author, contributor, copyrightHolder, editor, funder,
    producer, provider, sponsor
    TODO: sourceOrganization
    -->
    "publisher": [
      <xsl:for-each select="gmd:identificationInfo/*/gmd:pointOfContact/*">
        {
        <!-- TODO: Id could also be website if set -->
        <xsl:variable name="id"
                      select="gmd:contactInfo/*/gmd:address/*/gmd:electronicMailAddress/*/text()[1]"/>
        "@id":"<xsl:value-of select="$id"/>",
        "@type":"Organization"
        <xsl:for-each select="gmd:organisationName">
          ,"name": <xsl:apply-templates mode="toJsonLDLocalized"
                                       select="."/>
        </xsl:for-each>
        <xsl:for-each select="gmd:contactInfo/*/gmd:address/*/gmd:electronicMailAddress">
          ,"email": <xsl:apply-templates mode="toJsonLDLocalized"
                                       select="."/>
        </xsl:for-each>

        <!-- TODO: only if children available -->
        ,"contactPoint": {
          "@type" : "PostalAddress"
          <xsl:for-each select="gmd:contactInfo/*/gmd:address/*/gmd:country">
            ,"addressCountry": <xsl:apply-templates mode="toJsonLDLocalized"
                                                   select="."/>
          </xsl:for-each>
          <xsl:for-each select="gmd:contactInfo/*/gmd:address/*/gmd:city">
            ,"addressLocality": <xsl:apply-templates mode="toJsonLDLocalized"
                                                   select="."/>
          </xsl:for-each>
          <xsl:for-each select="gmd:contactInfo/*/gmd:address/*/gmd:postalCode">
            ,"postalCode": <xsl:apply-templates mode="toJsonLDLocalized"
                                                   select="."/>
          </xsl:for-each>
          <xsl:for-each select="gmd:contactInfo/*/gmd:address/*/gmd:deliveryPoint">
            ,"streetAddress": <xsl:apply-templates mode="toJsonLDLocalized"
                                                   select="."/>
          </xsl:for-each>
          }
        }
        <xsl:if test="position() != last()">,</xsl:if>
      </xsl:for-each>
    ]

    <xsl:for-each select="gmd:identificationInfo/*/gmd:citation/*/gmd:date[gmd:dateType/*/@codeListValue='publication']/*/gmd:date/*/text()">
      ,"datePublished": "<xsl:value-of select="."/>"
    </xsl:for-each>


    <!--
    The overall rating, based on a collection of reviews or ratings, of the item.
    "aggregateRating": TODO
    -->

    <!--
    A downloadable form of this dataset, at a specific location, in a specific format.

    See https://schema.org/DataDownload
    -->
    <xsl:for-each select="gmd:distributionInfo">
    ,"distribution": [
      <xsl:for-each select=".//gmd:onLine/*[gmd:linkage/gmd:URL != '']">
        {
        "@type":"DataDownload",
        "contentUrl":"<xsl:value-of select="gmd:linkage/gmd:URL/text()"/>",
        "encodingFormat":"<xsl:value-of select="gmd:protocol/gco:CharacterString/text()"/>"
        }
        <xsl:if test="position() != last()">,</xsl:if>
      </xsl:for-each>
    ]
    </xsl:for-each>

    <xsl:if test="count(gmd:distributionInfo/*/gmd:distributionFormat) > 0">
      ,"encodingFormat": [
      <xsl:for-each select="gmd:distributionInfo/*/gmd:distributionFormat/*/gmd:name[. != '']">
        <xsl:apply-templates mode="toJsonLDLocalized"
                             select="."/>
        <xsl:if test="position() != last()">,</xsl:if>
      </xsl:for-each>
      ]
    </xsl:if>



    <xsl:for-each select="gmd:identificationInfo/*/gmd:extent/*[gmd:geographicElement]">
    ,"spatialCoverage": {
      "@type":"Place"
      <xsl:for-each select="gmd:description[count(.//text() != '') > 0]">
      ,"description": <xsl:apply-templates mode="toJsonLDLocalized"
                                           select="."/>
      </xsl:for-each>


      <xsl:for-each select="gmd:geographicElement/gmd:EX_GeographicBoundingBox">
        ,"geo": {
          "@type":"GeoShape",
          "box": "<xsl:value-of select="string-join((
                                          gmd:southBoundLatitude/gco:Decimal|
                                          gmd:westBoundLongitude/gco:Decimal|
                                          gmd:northBoundLatitude/gco:Decimal|
                                          gmd:eastBoundLongitude/gco:Decimal
                                          ), ' ')"/>"
        }
      </xsl:for-each>
    }
    </xsl:for-each>


    <xsl:for-each select="gmd:identificationInfo/*/gmd:extent/*/gmd:temporalElement/*/gmd:extent">
      ,"temporalCoverage": "<xsl:value-of select="concat(
                                                  gml:TimePeriod/gml:beginPosition, '/',
                                                  gml:TimePeriod/gml:endPosition
      )"/>"
      <!-- TODO: handle
      "temporalCoverage" : "2013-12-19/.."
      "temporalCoverage" : "2008"
      -->
    </xsl:for-each>

    <xsl:for-each select="gmd:identificationInfo/*/gmd:resourceConstraints/gmd:MD_LegalConstraints/gmd:useLimitation">
      ,"license": <xsl:apply-templates mode="toJsonLDLocalized"
                                      select="."/>
    </xsl:for-each>

    <!-- TODO: When a dataset derives from or aggregates several originals, use the isBasedOn property. -->
    <!-- TODO: hasPart -->
	}
	</xsl:template>






  <xsl:template name="toJsonLDLocalized"
                mode="toJsonLDLocalized" match="*">
    <xsl:param name="asArray"
               select="true()"/>

    <xsl:choose>
      <!--
      This https://json-ld.org/spec/latest/json-ld/#string-internationalization
      should be supported in JSON-LD for multilingual content but does not
      seems to be supported yet by https://search.google.com/structured-data/testing-tool

      Error is not a valid type for property.

      So for now, JSON-LD format will only provide one language.
      The main one or the requested and if not found, the default.

      <xsl:when test="gmd:PT_FreeText">
        &lt;!&ndash; An array of object with all translations &ndash;&gt;
        <xsl:if test="$asArray">[</xsl:if>
        <xsl:for-each select="gmd:PT_FreeText/gmd:textGroup">
          <xsl:variable name="languageId"
                        select="gmd:LocalisedCharacterString/@locale"/>
          <xsl:variable name="languageCode"
                        select="$metadata/gmd:locale/*[concat('#', @id) = $languageId]/gmd:languageCode/*/@codeListValue"/>
          {
          <xsl:value-of select="concat('&quot;@value&quot;: &quot;',
                              gn-fn-index:json-escape(gmd:LocalisedCharacterString/text()),
                              '&quot;')"/>,
          <xsl:value-of select="concat('&quot;@language&quot;: &quot;',
                              $languageCode,
                              '&quot;')"/>
          }
          <xsl:if test="position() != last()">,</xsl:if>
        </xsl:for-each>
        <xsl:if test="$asArray">]</xsl:if>
        &lt;!&ndash;<xsl:if test="position() != last()">,</xsl:if>&ndash;&gt;
      </xsl:when>-->
      <xsl:when test="$requestedLanguage != ''">
        <xsl:variable name="requestedValue"
                      select="gmd:PT_FreeText/*/gmd:LocalisedCharacterString[@id = $requestedLanguageId]/text()"/>
        <xsl:value-of select="concat('&quot;',
                              gn-fn-index:json-escape(
                                if ($requestedValue != '') then $requestedValue else (gco:CharacterString|gmx:Anchor)),
                              '&quot;')"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- A simple property value -->
        <xsl:value-of select="concat('&quot;',
                              gn-fn-index:json-escape(gco:CharacterString|gmx:Anchor),
                              '&quot;')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
