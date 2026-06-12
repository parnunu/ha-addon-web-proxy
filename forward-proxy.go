package main

import (
	"bufio"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port            int      `json:"port"`
	AllowedNetworks []string `json:"allowed_networks"`
	MaxClients      int      `json:"max_clients"`
	ConnectPorts    []int    `json:"connect_ports"`
	UpstreamProxy   string   `json:"upstream_proxy"`
	LogLevel        string   `json:"log_level"`
}

type Proxy struct {
	cfg          Config
	allowedCIDRs []*net.IPNet
	allowedIPs   []net.IP
	connectPorts map[string]bool
	transport    *http.Transport
	upstreamURL  *url.URL
	sem          chan struct{}
}

func main() {
	configPath := flag.String("config", "/data/options.json", "Home Assistant add-on options JSON")
	flag.Parse()

	cfg, err := loadConfig(*configPath)
	if err != nil {
		log.Fatalf("configuration error: %v", err)
	}

	proxy, err := newProxy(cfg)
	if err != nil {
		log.Fatalf("configuration error: %v", err)
	}

	srv := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           proxy,
		ReadHeaderTimeout: 30 * time.Second,
		IdleTimeout:       120 * time.Second,
		ErrorLog:          log.New(os.Stderr, "http: ", log.LstdFlags),
	}

	log.Printf("starting lightweight forward proxy on 0.0.0.0:%d", cfg.Port)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("proxy stopped: %v", err)
	}
}

func loadConfig(path string) (Config, error) {
	cfg := Config{
		Port:            8888,
		AllowedNetworks: []string{"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"},
		MaxClients:      100,
		ConnectPorts:    []int{443, 563},
		LogLevel:        "Info",
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return cfg, err
	}
	if err := json.Unmarshal(data, &cfg); err != nil {
		return cfg, err
	}

	if cfg.Port < 1 || cfg.Port > 65535 {
		return cfg, fmt.Errorf("port must be between 1 and 65535")
	}
	if cfg.MaxClients < 1 || cfg.MaxClients > 10000 {
		return cfg, fmt.Errorf("max_clients must be between 1 and 10000")
	}
	if len(cfg.AllowedNetworks) == 0 {
		return cfg, fmt.Errorf("allowed_networks must contain at least one IP address or CIDR")
	}
	if len(cfg.ConnectPorts) == 0 {
		return cfg, fmt.Errorf("connect_ports must contain at least one port")
	}
	for _, p := range cfg.ConnectPorts {
		if p < 1 || p > 65535 {
			return cfg, fmt.Errorf("connect_ports entries must be between 1 and 65535")
		}
	}
	return cfg, nil
}

func newProxy(cfg Config) (*Proxy, error) {
	p := &Proxy{
		cfg:          cfg,
		connectPorts: map[string]bool{},
		sem:          make(chan struct{}, cfg.MaxClients),
	}

	for _, entry := range cfg.AllowedNetworks {
		entry = strings.TrimSpace(entry)
		if entry == "" {
			return nil, fmt.Errorf("allowed_networks entries must not be empty")
		}
		if strings.Contains(entry, "/") {
			_, cidr, err := net.ParseCIDR(entry)
			if err != nil {
				return nil, fmt.Errorf("invalid allowed network %q: %w", entry, err)
			}
			p.allowedCIDRs = append(p.allowedCIDRs, cidr)
			continue
		}
		ip := net.ParseIP(entry)
		if ip == nil {
			return nil, fmt.Errorf("invalid allowed IP %q", entry)
		}
		p.allowedIPs = append(p.allowedIPs, ip)
	}

	for _, port := range cfg.ConnectPorts {
		p.connectPorts[strconv.Itoa(port)] = true
	}

	transport := &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: (&net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		ForceAttemptHTTP2:     false,
		MaxIdleConns:          100,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   30 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}

	if strings.TrimSpace(cfg.UpstreamProxy) != "" {
		upstream, err := url.Parse("http://" + strings.TrimSpace(cfg.UpstreamProxy))
		if err != nil || upstream.Host == "" {
			return nil, fmt.Errorf("upstream_proxy must be host:port when set")
		}
		p.upstreamURL = upstream
		transport.Proxy = http.ProxyURL(upstream)
	}
	p.transport = transport
	return p, nil
}

func (p *Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	p.sem <- struct{}{}
	defer func() { <-p.sem }()

	if !p.clientAllowed(r.RemoteAddr) {
		http.Error(w, "proxy client not allowed", http.StatusForbidden)
		return
	}

	if r.Method == http.MethodConnect {
		p.handleConnect(w, r)
		return
	}
	p.handleHTTP(w, r)
}

func (p *Proxy) clientAllowed(remoteAddr string) bool {
	host, _, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		host = remoteAddr
	}
	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}
	for _, allowed := range p.allowedIPs {
		if allowed.Equal(ip) {
			return true
		}
	}
	for _, cidr := range p.allowedCIDRs {
		if cidr.Contains(ip) {
			return true
		}
	}
	return false
}

func (p *Proxy) handleHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL == nil || r.URL.Scheme == "" || r.URL.Host == "" {
		http.Error(w, "forward proxy requires absolute-form URL", http.StatusBadRequest)
		return
	}
	if r.URL.Scheme != "http" && r.URL.Scheme != "https" {
		http.Error(w, "unsupported URL scheme", http.StatusBadRequest)
		return
	}

	out := r.Clone(context.Background())
	out.RequestURI = ""
	removeHopByHopHeaders(out.Header)
	out.Header.Del("Proxy-Authorization")
	out.Header.Del("Proxy-Connection")

	resp, err := p.transport.RoundTrip(out)
	if err != nil {
		http.Error(w, "upstream request failed: "+err.Error(), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	removeHopByHopHeaders(resp.Header)
	copyHeader(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}

func (p *Proxy) handleConnect(w http.ResponseWriter, r *http.Request) {
	host, port, err := net.SplitHostPort(r.Host)
	if err != nil || host == "" || port == "" {
		http.Error(w, "CONNECT target must be host:port", http.StatusBadRequest)
		return
	}
	if !p.connectPorts[port] {
		http.Error(w, "CONNECT port not allowed", http.StatusForbidden)
		return
	}

	hijacker, ok := w.(http.Hijacker)
	if !ok {
		http.Error(w, "hijacking not supported", http.StatusInternalServerError)
		return
	}
	clientConn, _, err := hijacker.Hijack()
	if err != nil {
		return
	}

	var upstreamConn net.Conn
	if p.upstreamURL != nil {
		upstreamConn, err = net.DialTimeout("tcp", p.upstreamURL.Host, 30*time.Second)
		if err == nil {
			err = sendUpstreamConnect(upstreamConn, r.Host, p.upstreamURL)
		}
	} else {
		upstreamConn, err = net.DialTimeout("tcp", net.JoinHostPort(host, port), 30*time.Second)
	}

	if err != nil {
		_, _ = clientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n"))
		_ = clientConn.Close()
		return
	}

	_, _ = clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))
	tunnel(clientConn, upstreamConn)
}

func sendUpstreamConnect(conn net.Conn, target string, upstream *url.URL) error {
	req := &http.Request{
		Method: http.MethodConnect,
		URL:    &url.URL{Opaque: target},
		Host:   target,
		Header: make(http.Header),
	}
	if upstream.User != nil {
		username := upstream.User.Username()
		password, _ := upstream.User.Password()
		token := base64.StdEncoding.EncodeToString([]byte(username + ":" + password))
		req.Header.Set("Proxy-Authorization", "Basic "+token)
	}
	if err := req.Write(conn); err != nil {
		return err
	}
	resp, err := http.ReadResponse(bufio.NewReader(conn), req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		return fmt.Errorf("upstream CONNECT failed: %s", resp.Status)
	}
	return nil
}

func tunnel(a, b net.Conn) {
	defer a.Close()
	defer b.Close()
	done := make(chan struct{}, 2)
	go func() { _, _ = io.Copy(a, b); done <- struct{}{} }()
	go func() { _, _ = io.Copy(b, a); done <- struct{}{} }()
	<-done
}

func removeHopByHopHeaders(h http.Header) {
	for _, header := range strings.Split(h.Get("Connection"), ",") {
		if name := strings.TrimSpace(header); name != "" {
			h.Del(name)
		}
	}
	for _, name := range []string{"Connection", "Keep-Alive", "Proxy-Authenticate", "Proxy-Authorization", "Proxy-Connection", "Te", "Trailer", "Transfer-Encoding", "Upgrade"} {
		h.Del(name)
	}
}

func copyHeader(dst, src http.Header) {
	for k, vv := range src {
		for _, v := range vv {
			dst.Add(k, v)
		}
	}
}
