function patterns = mnist_noise_generator(base_patterns, P, num_copies, flip_frac)

    base_patterns = base_patterns(:,:,1:P);
    fprintf('Train set contains %d base patterns.\n', P);

    % Preallocate for efficiency
    % Each of P patterns will generate 1 + num_copies total images
    total = P * (1 + num_copies);
    [H,W,~] = size(base_patterns);
    patterns = zeros(H, W, total);

    for p = 1:P
        base_pat = base_patterns(:,:,p);

        % index where this pattern block starts in output
        idx0 = (p-1)*(1+num_copies) + 1;

        % 1. store original (clean) pattern
        patterns(:,:,idx0) = base_pat;

        % 2. generate noisy variants
        for c = 1:num_copies
            noisy = base_pat;
            num_flip = round(flip_frac * numel(base_pat));
            flip_idx = randperm(numel(base_pat), num_flip);
            noisy(flip_idx) = -noisy(flip_idx);

            patterns(:,:,idx0 + c) = noisy;
        end
    end

    fprintf('Generated %d total patterns = %d originals × (%d clean + %d noisy copies each).\n', ...
             size(patterns,3), P, 1, num_copies);
end
