package org.acme.getting.started.commandmode.valhalla.identity;

import org.acme.getting.started.commandmode.valhalla.model.URITemplate;

/**
 * Identity-class version of RESTEasy Reactive's RequestMapper.RequestMatch.
 * Original: org.jboss.resteasy.reactive.server.mapping.RequestMapper.RequestMatch
 *
 * Created on every HTTP request during route matching.
 * This is the baseline (current behavior) for benchmarking.
 *
 * Note: the template field uses URITemplate (not String) to match the actual Quarkus
 * source, where the field type is org.jboss.resteasy.reactive.server.mapping.URITemplate.
 */
public final class RequestMatchIdentity<T> {
    public final URITemplate template;
    public final T value;
    public final String[] pathParamValues;
    public final String remaining;

    public RequestMatchIdentity(URITemplate template, T value, String[] pathParamValues, String remaining) {
        this.template = template;
        this.value = value;
        this.pathParamValues = pathParamValues;
        this.remaining = remaining;
    }
}
