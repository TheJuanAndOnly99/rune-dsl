package com.regnosys.rosetta.ide.server;

import com.google.common.util.concurrent.ThreadFactoryBuilder;
import org.eclipse.xtext.ide.server.concurrent.AbstractRequest;
import org.eclipse.xtext.ide.server.concurrent.RequestManager;
import org.eclipse.xtext.service.OperationCanceledManager;
import org.eclipse.xtext.util.CancelIndicator;
import org.eclipse.xtext.xbase.lib.Functions.Function0;
import org.eclipse.xtext.xbase.lib.Functions.Function1;
import org.eclipse.xtext.xbase.lib.Functions.Function2;

import javax.inject.Inject;
import javax.inject.Singleton;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.*;

/**
 * A request manager that will time out after a configurable amount of seconds.
 * It can be configured through an environment variable.
 */
@Singleton
public class RosettaRequestManager extends RequestManager {
	public static String TIMEOUT_ENV_NAME = "ROSETTA_LANGUAGE_SERVER_REQUEST_TIMEOUT";
		
	private final Duration timeout;
	private final ScheduledExecutorService scheduler =
	        Executors.newScheduledThreadPool(
	                1,
	                new ThreadFactoryBuilder()
	                        .setDaemon(true)
	                        .setNameFormat("rosetta-language-server-request-timeout-%d")
	                        .build());

	/*
	 * The code that uses this list fixes a memory leak in the RequestManager and should be contributed
	 * back to the Xtext project then removed from here
	 */
	/* @ProtectedForTesting */
	protected List<AbstractRequest<?>> removableRequestList = new CopyOnWriteArrayList<>();

	@Inject
	public RosettaRequestManager(ExecutorService parallel, OperationCanceledManager operationCanceledManager) {
		super(parallel, operationCanceledManager);
		
		String rawTimeout = System.getenv(TIMEOUT_ENV_NAME);
		if (rawTimeout != null) {
			this.timeout = Duration.ofSeconds(Long.parseLong(rawTimeout));
		} else {
			this.timeout = null;
		}
	}

	@Override
	protected <V> CompletableFuture<V> submit(AbstractRequest<V> request) {
		addRequest(request);
		submitRequest(request);
		return request.get().whenComplete((result, error) -> removableRequestList.remove(request));
	}

	@Override
	protected void addRequest(AbstractRequest<?> request) {
		removableRequestList.add(request);
	}

	@Override
	protected CompletableFuture<Void> cancel() {
		List<AbstractRequest<?>> localRequests = removableRequestList;
		removableRequestList = new CopyOnWriteArrayList<>();
		CompletableFuture<?>[] cfs = new CompletableFuture<?>[localRequests.size()];
		for (int i = 0, max = localRequests.size(); i < max; i++) {
			AbstractRequest<?> request = localRequests.get(i);
			request.cancel();
			cfs[i] = request.get();
		}
		return CompletableFuture.allOf(cfs);
	}
	
	@Override
	public <V> CompletableFuture<V> runRead(Function1<? super CancelIndicator, ? extends V> cancellable) {
		return super.runRead((cancelIndicator) -> {		    
		    try {
		    	if (timeout == null) {
		    		return cancellable.apply(cancelIndicator);
		    	}
				return CompletableFuture.supplyAsync(
						() -> cancellable.apply(cancelIndicator),
						scheduler
					).get(timeout.toMillis(), TimeUnit.MILLISECONDS);
			} catch (Exception ex) {
				if (ex instanceof RuntimeException) {
					throw (RuntimeException)ex;
				}
				throw new RuntimeException(ex);
			}
		});
	}

	@Override
	public <U, V> CompletableFuture<V> runWrite(
			Function0<? extends U> nonCancellable,
			Function2<? super CancelIndicator, ? super U, ? extends V> cancellable) {
		return super.runWrite(nonCancellable, (cancelIndicator, intermediate) -> {		    
		    try {
		    	if (timeout == null) {
		    		return cancellable.apply(cancelIndicator, intermediate);
		    	}
				return CompletableFuture.supplyAsync(
						() -> cancellable.apply(cancelIndicator, intermediate),
						scheduler
					).get(timeout.toMillis(), TimeUnit.MILLISECONDS);
			} catch (Exception ex) {
				if (ex instanceof RuntimeException) {
					throw (RuntimeException)ex;
				}
				throw new RuntimeException(ex);
			}
		});
	}
}
