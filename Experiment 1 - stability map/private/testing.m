function testing(base_patterns,small_frame,full_frame,vid,cfg,map_idx,weights)
    P=size(base_patterns,3);
    pause(1);
    for kkk = 1:P
        pattern = base_patterns(:,:,kkk);                     % ±1 memory (N_x x N_y)
        % Get ONLY the signs of local fields at the mapped output pixels
        % for the pattern and its reverse
        lf_signs_pat = local_fields_calculator(pattern,small_frame,full_frame,vid,cfg,map_idx,weights,true);
        lf_signs_antipat = local_fields_calculator(-pattern,small_frame,full_frame,vid,cfg,map_idx,weights,true);
        % Compare with the memory spins (vectorized):
        agree = mean(double(lf_signs_pat(:)) .* double(pattern(:)));       % fraction in [0,1]
        anti_pattern = -pattern;
        anti_agree = mean(double(lf_signs_antipat(:)) .* double(anti_pattern(:)));
        
        fprintf(['Pattern %d: %.6f%% alignment with pattern, ' ...
         '%.6f%% alignment with antipattern\n'], kkk, 100*agree, 100*anti_agree);
    end
end