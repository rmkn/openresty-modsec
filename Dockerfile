FROM rmkn/centos7
LABEL maintainer "rmkn"

ENV OPENRESTY_VERSION 1.19.3.1
ENV MODSECURITY_NGINX_VERSION 1.0.1
ENV OWASP_CRS_VERSION 3.2.0
ENV NGINX_VERSION 1.19.3

RUN yum install -y      make gcc gcc-c++ pcre-devel ccache                           git libtool autoconf file                 yajl-devel curl-devel      GeoIP-devel doxygen unzip libxml2-devel

RUN curl -o /etc/yum.repos.d/openresty.repo https://openresty.org/package/centos/openresty.repo
RUN rpm --import https://openresty.org/package/pubkey.gpg
RUN yum install -y openresty openresty-zlib-devel openresty-pcre-devel openresty-openssl111-devel

RUN cd /usr/local/src \
	&& git clone https://github.com/SpiderLabs/ModSecurity \
	&& cd /usr/local/src/ModSecurity \
	&& ./build.sh \
	&& git submodule init \
	&& git submodule update \
	&& ./configure  \
	&& make \
	&& make install

RUN curl -o /usr/local/src/modsecurity-nginx.tar.gz -SL https://github.com/SpiderLabs/ModSecurity-nginx/archive/v${MODSECURITY_NGINX_VERSION}.tar.gz \
	&& tar zxf /usr/local/src/modsecurity-nginx.tar.gz -C /usr/local/src

RUN curl -o /usr/local/src/openresty.tar.gz -SL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz \
	&& tar zxf /usr/local/src/openresty.tar.gz -C /usr/local/src \
	&& cd /usr/local/src/openresty-${OPENRESTY_VERSION} \
	&& ./configure \
		--prefix="/usr/local/openresty" \
		--with-cc='ccache gcc -fdiagnostics-color=always' \
		--with-cc-opt="-DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/zlib/include -I/usr/local/openresty/pcre/include -I/usr/local/openresty/openssl111/include" \
		--with-ld-opt="-L/usr/local/openresty/zlib/lib -L/usr/local/openresty/pcre/lib -L/usr/local/openresty/openssl111/lib -Wl,-rpath,/usr/local/openresty/zlib/lib:/usr/local/openresty/pcre/lib:/usr/local/openresty/openssl111/lib" \
		--with-compat \
		--add-dynamic-module=/usr/local/src/ModSecurity-nginx-${MODSECURITY_NGINX_VERSION} \
	&& gmake \
	&& mkdir /usr/local/openresty/nginx/modules/ \
	&& cp -p ./build/nginx-${NGINX_VERSION}/objs/ngx_http_modsecurity_module.so /usr/local/openresty/nginx/modules/

RUN curl -o /usr/local/src/owasp-modsecurity-crs.tar.gz -SL https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v${OWASP_CRS_VERSION}.tar.gz \
	&& tar zxf /usr/local/src/owasp-modsecurity-crs.tar.gz -C /usr/local \
	&& cd /usr/local \
	&& ln -sf owasp-modsecurity-crs-${OWASP_CRS_VERSION} owasp-modsecurity-crs \
	&& mv /usr/local/owasp-modsecurity-crs/crs-setup.conf.example /usr/local/owasp-modsecurity-crs/crs-setup.conf

COPY nginx.conf /usr/local/openresty/nginx/conf/
COPY security.conf virtual.conf /usr/local/openresty/nginx/conf/conf.d/
COPY main.conf /usr/local/openresty/nginx/modsec/
COPY openssl.cnf /usr/local/openresty/openssl111/ssl/
RUN cp /usr/local/src/ModSecurity/modsecurity.conf-recommended /usr/local/openresty/nginx/modsec/modsecurity.conf 
RUN cp /usr/local/src/ModSecurity/unicode.mapping /usr/local/openresty/nginx/modsec/

EXPOSE 80 443

CMD ["/usr/bin/openresty", "-g", "daemon off;"]
