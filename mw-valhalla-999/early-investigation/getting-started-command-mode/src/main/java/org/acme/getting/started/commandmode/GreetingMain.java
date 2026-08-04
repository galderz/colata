package org.acme.getting.started.commandmode;

import jakarta.inject.Inject;

import io.quarkus.runtime.QuarkusApplication;
import io.quarkus.runtime.annotations.QuarkusMain;
import org.acme.getting.started.commandmode.valhalla.identity.RequestMatchIdentity;
import org.acme.getting.started.commandmode.valhalla.value.RequestMatchValue;
import org.jboss.resteasy.reactive.server.mapping.RequestMapper;
import org.jboss.resteasy.reactive.server.mapping.URITemplate;

@QuarkusMain
public class GreetingMain implements QuarkusApplication {

    @Inject
    GreetingService service;

    @Override
    public int run(String... args) {

        if(args.length>0) {
            System.out.println(service.greeting(String.join(" ", args)));
        } else {
            System.out.println(service.greeting("commando"));
        }

        final RequestMapper.RequestMatch<String> requestMatch = new RequestMapper.RequestMatch<>(
            new URITemplate("abc", false)
            , "def"
            , new String[]{"ghi", "jkl"}
            , "mno"
        );

        System.out.println(service.greeting(requestMatch.toString()));

        final RequestMatchIdentity<String> requestMatchIdentity = new RequestMatchIdentity<>(
            new org.acme.getting.started.commandmode.valhalla.model.URITemplate("abc")
            , "def"
            , new String[]{"ghi", "jkl"}
            , "mno"
        );

        System.out.println(service.greeting(requestMatchIdentity.toString()));

        final RequestMatchValue<String> requestMatchValue = new RequestMatchValue<>(
            new org.acme.getting.started.commandmode.valhalla.model.URITemplate("abc")
            , "def"
            , new String[]{"ghi", "jkl"}
            , "mno"
        );

        System.out.println(service.greeting(requestMatchValue.toString()));

        return 0;
    }


}
