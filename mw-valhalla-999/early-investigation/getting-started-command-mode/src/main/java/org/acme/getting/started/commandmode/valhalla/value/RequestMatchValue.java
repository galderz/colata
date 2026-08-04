package org.acme.getting.started.commandmode.valhalla.value;

import org.acme.getting.started.commandmode.valhalla.model.URITemplate;

/**
 * Value-class version of RESTEasy Reactive's RequestMapper.RequestMatch.
 * Original: org.jboss.resteasy.reactive.server.mapping.RequestMapper.RequestMatch
 *
 * As a value class, the JVM can:
 * - Scalarize the fields into registers when returned from map()
 * - Eliminate the object header (saves 12-16 bytes per instance)
 * - Stack-allocate without escape analysis
 *
 * Note: the template field uses URITemplate (not String) to match the actual Quarkus
 * source, where the field type is org.jboss.resteasy.reactive.server.mapping.URITemplate.
 */
public value class RequestMatchValue<T> {
    public final URITemplate template;
    public final T value;
    public final String[] pathParamValues;
    public final String remaining;

    public RequestMatchValue(URITemplate template, T value, String[] pathParamValues, String remaining) {
        this.template = template;
        this.value = value;
        this.pathParamValues = pathParamValues;
        this.remaining = remaining;
    }
}
