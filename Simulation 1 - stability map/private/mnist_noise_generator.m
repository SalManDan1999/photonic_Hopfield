function patterns=mnist_noise_generator(base_patterns,P,num_copies,flip_frac)
    base_patterns=base_patterns(:,:,1:P);
    fprintf('Train set contains %d frames.\n', P);
    imagesc(base_patterns(:,:,1));
    colormap gray; axis image off;
    title(['Sample pattern. Label = ' num2str(train_y(1))]);
    
    for p = 1:P
        base_pat = base_patterns(:,:,p);
        idx0 = (p-1)*2*(1+num_copies) + 1;  % step of 2*(1+num_copies) per pattern group
        
        % 1. clean pattern
        patterns(:,:,idx0) = base_pat;
        % 2. global flip of clean pattern
        patterns(:,:,idx0+1) = -base_pat;
        
        % 3. noisy copies and their flips
        for c = 1:num_copies
            noisy = base_pat;
            num_flip = round(flip_frac * numel(base_pat));
            flip_idx = randperm(numel(base_pat), num_flip);
            noisy(flip_idx) = -noisy(flip_idx);
            
            % store noisy and flipped-noisy
            base_offset = idx0 + 2*c;
            patterns(:,:,base_offset)   = noisy;
            patterns(:,:,base_offset+1) = -noisy;
        end
    end
    
    fprintf('Generated %d total patterns (%d originals × %d variants each ×2 for flips).\n', ...
            size(patterns,3), P, (1 + num_copies));
    
    % --- Show an example ---
    imagesc(patterns(:,:,1)); 
    colormap gray; axis image off;
    title(sprintf('Sample pattern (label=%d)', train_y(1)));
