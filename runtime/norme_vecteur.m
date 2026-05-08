function B=norme_vecteur(A)
n=sqrt(sum(A.^2,2));n(n==0)=1;
B=A./(n*ones(1,size(A,2)));
end
