function gpu_warm_up(PPP,Nneur)
    reset(gpuDevice);
    fprintf('\nWarming up GPU and JIT compiling kernels... ');
    % Crea dati dummy delle dimensioni massime che userai nell'esperimento
    max_p = max(PPP(:));
    dummy_A = rand(Nneur, max_p, 'single'); % O 'double' se usi double
    dummy_B = rand(max_p, Nneur, 'single'); 
    
    % Sposta su GPU
    gA = gpuArray(dummy_A);
    gB = gpuArray(dummy_B);
    
    % Esegui l'operazione pesante (GEMM) per forzare la compilazione del Kernel
    gC = gA * gB;
    % Forza la sincronizzazione per assicurarsi che abbia finito
    wait(gpuDevice);
    
    % Pulisci le variabili dummy ma NON resettare il device
    clear gA gB gC dummy_A dummy_B;
    fprintf('Done.\n');
end